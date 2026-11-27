import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../features/admin/qr/data/model/scan_attendance_new/attendance_class_choice_model.dart';
import 'offline_pack.dart';
import 'offline_store.dart';
import 'offline_sync.dart';

/// Answers the staff screens from the day's pack when there is no internet,
/// in the same shape as the server, and queues what was done:
///
///  - attendance scan   (POST /new-attendance/scan)
///  - payment read      (POST /new-payment/read)
///  - month info        (POST /new-payment/month-info)
///  - payments          (POST /new-payment/bulk-pay)
///
/// The same rules as the server: the class must be open (attendance
/// window), a month already paid (on the pack or on this phone) cannot be
/// paid again, the amount must cover the fee unless Payment Rules allow less.
class OfflineEngine {
  OfflineEngine._();

  /// No internet / server not reachable (not a refusal by the server).
  static bool isNetworkError(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is HandshakeException;

  /// Time limit of the online call before working offline.
  static const timeout = Duration(seconds: 10);

  /* ------------------------------------------------------------ pack */

  static Future<OfflinePack> _pack() => OfflinePack.load();

  /* ------------------------------------------------------ attendance */

  /// The body of a POST /new-attendance/scan answer (success, message, data).
  static Future<Map<String, dynamic>> scanAttendance({
    required String code,
    required String markMethod,
    int? scheduleId,
  }) async {
    final pack = await _pack();
    final student = pack.studentByCode(code);
    if (student == null) {
      throw Exception('Student not found (offline). Check the card or download today\'s data again.');
    }

    final studentId = _int(student['id']);
    final now = DateTime.now();
    final open = pack.openClasses(studentId, now);

    if (open.isEmpty) {
      throw Exception('No active class found for this student at this time.');
    }

    OfflineOpenClass current;
    if (scheduleId != null) {
      final match = open.where((o) => _int(o.schedule['id']) == scheduleId);
      if (match.isEmpty) throw Exception('The selected class is not open for attendance now.');
      current = match.first;
    } else if (open.length > 1) {
      throw ClassSelectionRequiredException(
        message: 'This student has ${open.length} classes now. Choose the class to mark attendance.',
        studentName: (student['name'] ?? '').toString(),
        studentCode: (student['custom_id'] ?? code).toString(),
        classes: open
            .map((o) => AttendanceClassChoiceModel.fromJson({
                  ..._scheduleJson(o.schedule),
                  'schedule_id': o.schedule['id'],
                  'is_started': !now.isBefore(DateTime.parse(o.schedule['start_at'].toString()).toLocal()),
                  'already_marked': pack.attendanceMarked(studentId, _int(o.schedule['id'])),
                }))
            .toList(),
      );
    } else {
      current = open.first;
    }

    final scheduleIdNow = _int(current.schedule['id']);
    final already = pack.attendanceMarked(studentId, scheduleIdNow);

    if (!already) {
      await OfflineStore.addToQueue({
        'local_uuid': OfflineStore.uuid(),
        'type': 'attendance',
        'happened_at': OfflineStore.timestamp(now),
        'student_id': studentId,
        'enrollment_id': _int(current.enrollment['id']),
        ...pack.refs(studentId: studentId, enrollmentId: _int(current.enrollment['id'])),
        'schedule_id': scheduleIdNow,
        'mark_method': markMethod == 'manual_mobile' ? 'manual_mobile' : 'qr_mobile',
        '_status': 'pending',
        '_label': '${student['name']} - ${current.schedule['class_name']}',
      });
      OfflineSync.instance.queued();
    }

    final month = _month(now);
    final paid = pack.isMonthPaid(current.enrollment, month);
    final fee = _num(current.enrollment['payable']);
    final freeCard = current.enrollment['is_free_card'] == true;

    return {
      'success': true,
      'message': already
          ? 'Attendance already marked for this class (offline).'
          : 'Attendance saved on this phone (offline). It will be sent when online.',
      'data': {
        'student': _studentJson(student),
        'schedule': _scheduleJson(current.schedule),
        'enrollment': _enrollmentJson(current.enrollment),
        'last_payment': null,
        'current_month_payment': {
          'month': month,
          'month_name': _monthName(month),
          'status': freeCard ? 'free' : (paid ? 'paid' : 'unpaid'),
          'is_paid': freeCard || paid,
          'fee': fee,
          'paid_amount': paid ? fee : 0,
          'balance': (freeCard || paid) ? 0 : fee,
        },
        'attendance': {
          'id': null,
          'status': 'present',
          'marked_at': _dateTime(now),
          'mark_method': markMethod,
          'already_marked': already,
        },
        'attendance_summary': {
          'month': month,
          'total_count': 0,
          'present_count': 0,
          'absent_count': 0,
          'attendance_percentage': 0,
        },
        'tute': {'month': month, 'is_issued': false, 'issued_at': null, 'note': null},
        'offline': true,
      },
    };
  }

  /* --------------------------------------------------------- payment */

  /// The `data` of a POST /new-payment/read answer (student, classes).
  static Future<Map<String, dynamic>> readPayment(String code) async {
    final pack = await _pack();
    final student = pack.studentByCode(code);
    if (student == null) {
      throw Exception('Student not found (offline). Check the card or download today\'s data again.');
    }

    final month = _month(DateTime.now());
    final classes = pack.enrollmentsOf(_int(student['id'])).map((enrollment) {
      final schedule = pack.classInfo(enrollment);
      final paid = pack.isMonthPaid(enrollment, month);
      final fee = _num(enrollment['payable']);
      final option = enrollment['fee_option'];

      return {
        'enrollment_id': enrollment['id'],
        'is_free_card': enrollment['is_free_card'] == true,
        'class_name': schedule['class_name'] ?? '',
        'subject': schedule['subject'] ?? '',
        'grade': schedule['grade'] ?? '',
        'teacher_initials': schedule['teacher'] ?? '',
        'category_name': schedule['category'] ?? '',
        'category_id': null,
        'fee_id': enrollment['class_category_fee_id'],
        'fee_option': option,
        'class_fee': enrollment['class_fee'],
        'hall_fee': enrollment['hall_fee'],
        'total_fee': fee,
        'final_fee': fee,
        'balance': paid ? 0 : fee,
        'payment_status': enrollment['is_free_card'] == true ? 'free' : (paid ? 'paid' : 'unpaid'),
        'attendance': {'class_days': 0, 'attended_days': 0},
        'last_payment': null,
      };
    }).toList();

    return {
      'student': {
        'id': student['id'],
        'custom_id': student['custom_id'],
        'student_code': student['custom_id'],
        'full_name': student['full_name'] ?? student['name'],
        'initial_name': student['initial_name'] ?? student['name'],
        'image_url': null,
        'mobile': null,
        'guardian_mobile': null,
        'guardian_name': null,
        'grade': student['grade'],
      },
      'classes': classes,
      'offline': true,
    };
  }

  /// The `data` of a POST /new-payment/month-info answer.
  static Future<Map<String, dynamic>> monthInfo({
    required String code,
    required int enrollmentId,
    required String paymentMonth,
  }) async {
    final pack = await _pack();
    final enrollment = pack.enrollment(enrollmentId);
    if (enrollment == null) throw Exception('Class not found (offline).');

    final month = paymentMonth.length >= 7 ? paymentMonth.substring(0, 7) : paymentMonth;
    final rules = pack.paymentRules;
    final hall = _num(enrollment['hall_fee']);
    final studentOptionId = enrollment['fee_option'] is Map ? _int(enrollment['fee_option']['id']) : 0;
    final options = pack.feeOptions(_int(enrollment['class_category_fee_id']))
        .map((o) => {
              'id': o['id'],
              'label': o['label'],
              'amount': _num(o['fee']) + hall,
              'is_student_option': _int(o['id']) == studentOptionId,
            })
        .toList();

    return {
      'enrollment_id': enrollmentId,
      'payment_month_name': _monthName(month),
      'attendance_count': 0,
      'no_attendance': false,
      'gross_fee': _num(enrollment['payable']),
      'fee_option_enabled': rules['fee_option'] == true,
      'fee_options': options,
      'custom_amount': rules['custom_amount'] == true,
      'already_paid': pack.isMonthPaid(enrollment, month),
      'paid': null,
      'tute': {'enabled': false, 'issued': false, 'issued_at': null},
    };
  }

  /// The `data` of a POST /new-payment/bulk-pay answer. Each payment gets an
  /// offline receipt number (OF-A3F2-0007) and waits in the queue.
  static Future<Map<String, dynamic>> bulkPay(List<Map<String, dynamic>> items) async {
    final pack = await _pack();
    if (items.isEmpty) throw Exception('No payment selected.');

    final now = DateTime.now();
    final rules = pack.paymentRules;
    final checked = <Map<String, dynamic>>[];

    // check everything first: nothing is saved if one is wrong
    for (final item in items) {
      final enrollment = pack.enrollment(_int(item['enrollment_id']));
      if (enrollment == null) throw Exception('Class not found (offline).');

      final month = item['payment_month'].toString().substring(0, 7);
      if (pack.isMonthPaid(enrollment, month)) {
        throw Exception('Payment already completed for this class and month.');
      }

      final amount = _num(item['amount']);
      final discount = _num(item['discount_amount']);
      final payable = _num(enrollment['payable']) - discount;
      if (amount <= 0) throw Exception('Payment amount must be greater than zero.');

      if (amount + 0.009 < payable) {
        var minimum = payable;
        final optionId = item['fee_option_id'];
        if (rules['fee_option'] == true && optionId != null) {
          for (final o in pack.feeOptions(_int(enrollment['class_category_fee_id']))) {
            if (_int(o['id']) == _int(optionId)) {
              minimum = _num(o['fee']) + _num(enrollment['hall_fee']);
            }
          }
        }
        if (rules['custom_amount'] == true) minimum = 0;
        if (amount + 0.009 < minimum) {
          throw Exception('Payment amount must be at least Rs. ${minimum.toStringAsFixed(2)}.');
        }
      }

      checked.add({'item': item, 'enrollment': enrollment, 'month': month});
    }

    final student = pack.studentById(_int(checked.first['enrollment']['student_id']));
    final payments = <Map<String, dynamic>>[];
    final receiptClasses = <Map<String, dynamic>>[];
    var total = 0.0;
    var hallTotal = 0.0;
    var feeTotal = 0.0;

    for (final c in checked) {
      final item = c['item'] as Map<String, dynamic>;
      final enrollment = c['enrollment'] as Map<String, dynamic>;
      final schedule = pack.classInfo(enrollment);
      final receipt = await OfflineStore.nextReceiptNumber();
      final amount = _num(item['amount']);

      await OfflineStore.addToQueue({
        'local_uuid': OfflineStore.uuid(),
        'type': 'payment',
        'happened_at': OfflineStore.timestamp(now),
        'student_id': _int(enrollment['student_id']),
        'enrollment_id': _int(enrollment['id']),
        ...pack.refs(studentId: _int(enrollment['student_id']), enrollmentId: _int(enrollment['id'])),
        'payment_month': c['month'],
        'amount': amount,
        'discount_amount': _num(item['discount_amount']),
        if (item['fee_option_id'] != null) 'fee_option_id': _int(item['fee_option_id']),
        'mark_method': item['mark_method'] == 'manual_mobile' ? 'manual_mobile' : 'qr_mobile',
        'receipt_number': receipt,
        '_status': 'pending',
        '_label': '${student?['name'] ?? ''} - ${schedule['class_name'] ?? ''} - ${_monthName(c['month'] as String)} - Rs. ${amount.toStringAsFixed(2)}',
      });

      total += amount;
      hallTotal += _num(enrollment['hall_fee']);
      feeTotal += _num(enrollment['payable']);

      payments.add({
        'id': null,
        'amount': amount,
        'discount_amount': _num(item['discount_amount']),
        'fee': _num(enrollment['payable']),
        'paid_at': _dateTime(now),
        'payment_method': 'cash',
        'payment_month': c['month'],
        'receipt_number': receipt,
        'status': 'completed',
      });

      final option = enrollment['fee_option'];
      receiptClasses.add({
        'class_name': schedule['class_name'] ?? '',
        'category_name': schedule['category'] ?? '',
        'grade': schedule['grade'] ?? '',
        'teacher_name': schedule['teacher_name'] ?? schedule['teacher'] ?? '',
        'fee_option_name': option is Map ? option['label'] : '',
        'class_fee': enrollment['class_fee'],
        'hall_fee': enrollment['hall_fee'],
        'paid_amount': amount,
        'receipt_no': receipt,
      });
    }

    OfflineSync.instance.queued();

    return {
      'payments': payments,
      'receipt': {
        'student_details': {
          'student_id': student?['id'],
          'name': student?['name'] ?? '',
          'custom_id': student?['custom_id'] ?? '',
        },
        'classes': receiptClasses,
        'total': total,
        'payment_method': 'cash',
        'payment_count': payments.length,
      },
      'count': payments.length,
      'total_final_fee': feeTotal - hallTotal,
      'total_hall_fee': hallTotal,
      'total_gross_fee': feeTotal,
      'total_discount': 0,
      'total_payable': feeTotal,
      'total_paid': total,
      'total_balance': (feeTotal - total) > 0 ? feeTotal - total : 0,
      'paid_at': _dateTime(now),
      'print_receipt': rules['print_receipt'] != false,
      'offline': true,
    };
  }

  /* ---------------------------------------------------------- json */

  static Map<String, dynamic> _studentJson(Map<String, dynamic> s) => {
        'id': s['id'],
        'student_code': s['custom_id'],
        'custom_id': s['custom_id'],
        'full_name': s['full_name'] ?? s['name'],
        'initial_name': s['initial_name'] ?? s['name'],
        'guardian_mobile': null,
        'img_url': null,
        'grade': s['grade'],
        'grade_name': s['grade'],
      };

  static Map<String, dynamic> _scheduleJson(Map<String, dynamic> s) => {
        'id': s['id'],
        'branch': s['branch'],
        'class_date': s['class_date'],
        'start_time': s['start_time'],
        'end_time': s['end_time'],
        'hall': s['hall'] ?? '',
        'class': {
          'id': s['student_class_id'],
          'class_name': s['class_name'] ?? '',
          'teacher': s['teacher_name'] ?? s['teacher'] ?? '',
          'subject': s['subject'] ?? '',
          'grade': s['grade'] ?? '',
          'category': s['category'] ?? '',
        },
      };

  static Map<String, dynamic> _enrollmentJson(Map<String, dynamic> e) {
    final option = e['fee_option'];
    return {
      'id': e['id'],
      'student_class_id': e['student_class_id'],
      'class_category_fee_id': e['class_category_fee_id'],
      'class_category_fee_option_id': option is Map ? option['id'] : null,
      'final_fee': e['is_free_card'] == true ? 0 : (option is Map ? option['fee'] : e['class_fee']),
      'is_free_card': e['is_free_card'] == true,
      'class_category_fee_option': option,
    };
  }

  static int _int(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _date(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';
  static String _month(DateTime t) => '${t.year}-${_two(t.month)}';
  static String _dateTime(DateTime t) => '${_date(t)} ${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _monthName(String month) {
    final parts = month.split('-');
    if (parts.length < 2) return month;
    final m = int.tryParse(parts[1]) ?? 1;
    return '${_monthNames[(m - 1).clamp(0, 11)]} ${parts[0]}';
  }
}
