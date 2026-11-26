import 'offline_pack.dart';
import 'offline_store.dart';
import 'offline_sync.dart';

/// Registering a student and adding a class without internet, answered from
/// today's pack in the same shape as the server:
///
///  - grades              (GET  /grades)
///  - admissions          (GET  /admission)
///  - card scan           (POST /qr-code)                      permanent cards
///  - register            (POST /student, POST /student-new)
///  - student's classes   (POST /student-class-enrollments/read-student-class)
///  - classes of a grade  (GET  /student-classes/{grade})
///  - add a class         (POST /student-class-enrollments)
///
/// A new student or class gets a negative id on the phone; the attendance
/// and payments taken for it point to it until the server saves it.
class OfflineStudents {
  OfflineStudents._();

  static int _int(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _date(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';
  static String _dateTime(DateTime t) => '${_date(t)} ${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

  /* ------------------------------------------------------------ lists */

  static Future<Map<String, dynamic>> grades() async {
    final pack = await OfflinePack.load();
    return {'success': true, 'status': 'success', 'data': pack.grades, 'offline': true};
  }

  static Future<Map<String, dynamic>> admissions() async {
    final pack = await OfflinePack.load();
    return {'success': true, 'data': pack.admissions, 'offline': true};
  }

  static Future<Map<String, dynamic>> classesByGrade(int gradeId) async {
    final pack = await OfflinePack.load();
    return {
      'success': true,
      'message': 'Classes from today\'s offline data.',
      'grade': {'id': gradeId, 'grade_name': pack.gradeName(gradeId) ?? ''},
      'data': pack.classes.where((c) => _int(c['grade_id']) == gradeId).toList(),
      'offline': true,
    };
  }

  /* ------------------------------------------------------------- card */

  /// Permanent card scanned to register a student (POST /qr-code).
  static Future<Map<String, dynamic>> scanCard(String code) async {
    final pack = await OfflinePack.load();
    final qr = code.trim().toUpperCase();

    final student = pack.studentByCode(qr);
    if (student != null) {
      throw Exception('This card is already given to ${student['name'] ?? 'a student'} (offline).');
    }
    if (pack.cardUsedOnPhone(qr)) {
      throw Exception('This card was already given to a student on this phone.');
    }

    final card = pack.card(qr);
    if (card == null) {
      throw Exception('Card not found in today\'s offline data. Use another card, or connect to the internet.');
    }

    return {
      'status': true,
      'message': 'Card available (offline).',
      'card': {
        'branch_id': card['branch_id'],
        'branch': card['branch'],
        'card_number': card['card_number'],
      },
    };
  }

  /* --------------------------------------------------------- register */

  /// A student registered offline (the body of the app's registration call).
  /// Returns the server's answer shape (success, student, admission_payment).
  static Future<Map<String, dynamic>> register(Map<String, dynamic> form) async {
    final pack = await OfflinePack.load();
    final temporary = pack.cardMode == 'temporary';
    final cardKey = temporary ? 'temporary_qr_code' : 'card_qr_code';
    final card = (form[cardKey] ?? '').toString().trim().toUpperCase();

    if (card.isEmpty || card == 'TMP') {
      throw Exception(temporary
          ? 'No internet: type the number of the card you give the student (Different card).'
          : 'Scan the student card first.');
    }
    if (pack.studentByCode(card) != null || pack.cardUsedOnPhone(card)) {
      throw Exception('Card $card is already given to another student.');
    }
    if (pack.card(card) == null) {
      throw Exception('Card $card is not a card that can be given now (offline data). Use another card.');
    }

    final name = (form['initial_name'] ?? '').toString().trim();
    final gradeId = _int(form['grade_id']);
    if (name.isEmpty) throw Exception('Initial name is required.');
    if (gradeId == 0) throw Exception('Please select grade.');

    final now = DateTime.now();
    final uuid = OfflineStore.uuid();
    final localId = await OfflineStore.nextLocalId();

    final student = Map<String, dynamic>.from(form)..[cardKey] = card;
    student.remove(temporary ? 'card_qr_code' : 'temporary_qr_code');

    // a photo taken without internet is uploaded after the student is saved
    final photo = student['quick_image_id']?.toString();
    if (OfflineStore.isOfflinePhoto(photo)) student.remove('quick_image_id');

    // admission paid now: an offline receipt, as for class fees
    Map<String, dynamic>? admission;
    final admissionId = _int(form['admission_id']);
    if (admissionId > 0) {
      final item = pack.admissions.where((a) => _int(a['id']) == admissionId);
      if (item.isEmpty) throw Exception('Admission not found (offline).');
      admission = {
        'id': 0,
        'receipt_number': await OfflineStore.nextReceiptNumber(),
        'amount': _num(item.first['amount']).toStringAsFixed(2),
        'status': 'paid',
        'paid_at': _dateTime(now),
        'payment_method': 'cash',
        'admission_name': item.first['name']?.toString() ?? '',
      };
    }

    final grade = pack.gradeName(gradeId);

    await OfflineStore.addToQueue({
      'local_uuid': uuid,
      'type': 'student',
      'happened_at': OfflineStore.timestamp(now),
      'student': student,
      if (admission != null) 'admission_receipt_number': admission['receipt_number'],
      '_status': 'pending',
      '_label': 'New student: $name - $card',
      if (OfflineStore.isOfflinePhoto(photo)) '_photo': photo,
      // used like a student from the server until it is sent
      '_row': {
        'id': localId,
        '_ref': uuid,
        'custom_id': temporary ? null : card,
        'temporary_qr_code': temporary ? card : null,
        'codes': [card],
        'name': name,
        'initial_name': name,
        'full_name': name,
        'grade_id': gradeId,
        'grade': grade,
        'offline': true,
      },
    });
    OfflineSync.instance.queued();

    return {
      'success': true,
      'message': 'Student saved on this phone (offline). The Custom ID is given when it is sent.',
      'student': {
        'id': localId,
        'branch_id': form['branch_id'],
        'custom_id': temporary ? null : card,
        'temporary_qr_code': temporary ? card : null,
        'initial_name': name,
        'gender': form['gender'],
        'guardian_mobile': form['guardian_mobile'],
        'grade_id': gradeId,
        'grade': grade == null ? null : {'id': gradeId, 'grade_name': grade},
        'admission': admission != null ? 1 : 0,
        'is_active': true,
      },
      'card': {'custom_id': temporary ? null : card, 'temporary_qr_code': temporary ? card : null},
      'admission_payment': admission,
      'offline': true,
    };
  }

  /* ---------------------------------------------------------- classes */

  /// The student and their classes (POST read-student-class). Offline only
  /// today's classes and the classes added on this phone are known.
  static Future<Map<String, dynamic>> studentClasses(String code) async {
    final pack = await OfflinePack.load();
    final student = pack.studentByCode(code);
    if (student == null) {
      throw Exception('Student not found (offline). Check the card or download today\'s data again.');
    }

    final month = '${DateTime.now().year}-${_two(DateTime.now().month)}';
    final classes = pack.enrollmentsOf(_int(student['id'])).map((e) {
      final info = pack.classInfo(e);
      final option = e['fee_option'] is Map ? Map<String, dynamic>.from(e['fee_option'] as Map) : null;
      final paid = pack.isMonthPaid(e, month);
      final fee = _num(e['payable']);
      final free = e['is_free_card'] == true;

      return {
        'enrollment_id': e['id'],
        'class_id': e['student_class_id'],
        'class_name': info['class_name'] ?? '',
        'grade_name': info['grade'] ?? '',
        'teacher_name': info['teacher_name'] ?? info['teacher'] ?? '',
        'class_category_fee_id': e['class_category_fee_id'],
        'category_name': info['category'] ?? '',
        'class_category_fee_option_id': option?['id'] ?? 0,
        'fee_option': option,
        'is_active': true,
        'is_free_card': free,
        'final_fee': free ? 0 : _num(option?['fee']),
        'paid_amount': paid ? fee : 0,
        'balance': (free || paid) ? 0 : fee,
        'payment_status': free ? 'free' : (paid ? 'paid' : 'unpaid'),
        'registered_date': null,
      };
    }).toList();

    return {
      'success': true,
      'message': 'Offline: only today\'s classes and the classes added on this phone are shown.',
      'student': {
        'id': student['id'],
        // the code to find the student again (a new temporary-card student has no Custom ID yet)
        'custom_id': student['custom_id'] ?? (student['codes'] as List?)?.first,
        'temporary_qr_code': student['temporary_qr_code'],
        'initial_name': student['initial_name'] ?? student['name'],
        'img_url': null,
        'grade_id': student['grade_id'],
        'grade_name': student['grade'],
      },
      'data': classes,
      'offline': true,
    };
  }

  /// A class added to a student offline (POST /student-class-enrollments body).
  static Future<Map<String, dynamic>> enroll(Map<String, dynamic> request) async {
    final pack = await OfflinePack.load();
    final studentId = _int(request['student_id']);
    final classId = _int(request['student_class_id']);
    final feeId = _int(request['class_category_fee_id']);
    final optionId = _int(request['class_category_fee_option_id']);
    final free = request['is_free_card'] == true;

    final student = pack.studentById(studentId);
    if (student == null) throw Exception('Student not found (offline).');

    final klass = pack.classById(classId);
    final category = klass == null ? null : pack.categoryFee(klass, feeId);
    if (klass == null || category == null) throw Exception('Selected class is invalid or inactive.');

    final options = (category['fee_options'] as List? ?? const []).whereType<Map>().where((o) => _int(o['id']) == optionId);
    if (options.isEmpty) throw Exception('Selected fee option is invalid or inactive.');
    final option = Map<String, dynamic>.from(options.first);

    final already = pack.enrollmentsOf(studentId).any((e) =>
        _int(e['student_class_id']) == classId &&
        _int(e['class_category_fee_id']) == feeId &&
        e['fee_option'] is Map &&
        _int((e['fee_option'] as Map)['id']) == optionId);
    if (already) throw Exception('Student is already enrolled with this class category and fee option.');

    final now = DateTime.now();
    final uuid = OfflineStore.uuid();
    final localId = await OfflineStore.nextLocalId();
    final hall = _num(category['hall_fee']);
    final classFee = free ? 0.0 : _num(option['fee']);

    await OfflineStore.addToQueue({
      'local_uuid': uuid,
      'type': 'enrollment',
      'happened_at': OfflineStore.timestamp(now),
      'student_id': studentId,
      ...pack.refs(studentId: studentId),
      'student_class_id': classId,
      'class_category_fee_id': feeId,
      'class_category_fee_option_id': optionId,
      'is_free_card': free,
      if (request['note'] != null) 'note': request['note'].toString().length > 200 ? request['note'].toString().substring(0, 200) : request['note'],
      '_status': 'pending',
      '_label': 'Class added: ${student['name'] ?? ''} - ${klass['class_name'] ?? ''} (${category['category_name'] ?? ''})',
      // used like an enrollment from the server until it is sent
      '_row': {
        'id': localId,
        '_ref': uuid,
        'student_id': studentId,
        'student_class_id': classId,
        'class_category_fee_id': feeId,
        'is_free_card': free,
        'fee_option': {
          'id': optionId,
          'class_category_fee_id': feeId,
          'label': option['label'],
          'fee': _num(option['fee']),
          'is_default': option['is_default'] == true,
          'is_active': true,
        },
        'class_fee': classFee,
        'hall_fee': hall,
        'payable': classFee + hall,
        'paid_months': const [],
        'offline': true,
      },
    });
    OfflineSync.instance.queued();

    return {
      'success': true,
      'message': 'Class added on this phone (offline). It will be sent when online.',
      'data': {
        'enrollment_id': localId,
        'student_id': studentId,
        'student_class_id': classId,
        'class_category_fee_id': feeId,
        'class_category_fee_option_id': optionId,
        'is_active': true,
        'is_free_card': free,
        'final_fee': classFee,
        'registered_date': _date(now),
      },
      'offline': true,
    };
  }
}
