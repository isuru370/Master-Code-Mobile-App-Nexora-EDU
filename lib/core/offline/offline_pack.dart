import 'offline_store.dart';

/// A class of the student that is open for attendance now.
class OfflineOpenClass {
  OfflineOpenClass(this.schedule, this.enrollment);
  final Map<String, dynamic> schedule;
  final Map<String, dynamic> enrollment;
}

/// Today's pack (GET /api/offline/pack) together with what this phone did
/// offline and has not sent yet: a student registered or a class added on
/// the phone is used like one from the server. They have a negative id
/// (-1, -2 ...) until the server saves them; items for them carry
/// student_ref / enrollment_ref (the local_uuid of the student / class item).
class OfflinePack {
  OfflinePack(this.json, this.queue);

  final Map<String, dynamic> json;
  final List<Map<String, dynamic>> queue;

  static Future<OfflinePack> load() async {
    final json = await OfflineStore.readPack();
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (json == null || json['date'] != today) {
      throw Exception(
        'No internet, and today\'s offline data is not on this phone. '
        'Connect to the internet once to download it.',
      );
    }
    return OfflinePack(json, await OfflineStore.readQueue());
  }

  static int _int(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  List<Map<String, dynamic>> _list(String key, [Map<String, dynamic>? from]) =>
      ((from ?? json)[key] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  /// Students / classes made on this phone, not on the server yet.
  List<Map<String, dynamic>> _local(String type) => queue
      .where((q) => q['type'] == type && q['_status'] == 'pending' && q['_row'] is Map)
      .map((q) => Map<String, dynamic>.from(q['_row'] as Map))
      .toList();

  late final List<Map<String, dynamic>> schedules = _list('schedules');
  late final List<Map<String, dynamic>> students = [..._list('students'), ..._local('student')];
  late final List<Map<String, dynamic>> _localEnrollments = _local('enrollment');

  /// A class added on the phone replaces the student's other fee option of
  /// the same class + category (as the server does).
  late final List<Map<String, dynamic>> enrollments = [
    ..._list('enrollments').where((e) => !_localEnrollments.any((l) => _sameGroup(l, e))),
    ..._localEnrollments,
  ];

  late final List<Map<String, dynamic>> classes = _list('classes');
  late final List<Map<String, dynamic>> grades = _list('grades');
  late final List<Map<String, dynamic>> admissions = _list('admissions');

  Map<String, dynamic> get registration {
    final r = json['registration'];
    return r is Map ? Map<String, dynamic>.from(r) : const {};
  }

  String get cardMode => registration['card_mode']?.toString() ?? 'permanent';

  List<Map<String, dynamic>> get cards => _list('cards', registration);

  Map<String, dynamic> get paymentRules {
    final rules = json['rules'];
    final payment = rules is Map ? rules['payment'] : null;
    return payment is Map ? Map<String, dynamic>.from(payment) : const {};
  }

  static bool _sameGroup(Map<String, dynamic> a, Map<String, dynamic> b) =>
      _int(a['student_id']) == _int(b['student_id']) &&
      _int(a['student_class_id']) == _int(b['student_class_id']) &&
      _int(a['class_category_fee_id']) == _int(b['class_category_fee_id']);

  Map<String, dynamic>? studentByCode(String code) {
    final wanted = code.trim().toUpperCase();
    for (final s in students) {
      final codes = (s['codes'] as List? ?? const []).map((c) => c.toString().toUpperCase());
      if (codes.contains(wanted)) return s;
    }
    return null;
  }

  Map<String, dynamic>? studentById(int id) {
    for (final s in students) {
      if (_int(s['id']) == id) return s;
    }
    return null;
  }

  Map<String, dynamic>? enrollment(int id) {
    for (final e in enrollments) {
      if (_int(e['id']) == id) return e;
    }
    return null;
  }

  List<Map<String, dynamic>> enrollmentsOf(int studentId) =>
      enrollments.where((e) => _int(e['student_id']) == studentId).toList();

  /// student_ref / enrollment_ref for a student / class made on this phone.
  Map<String, dynamic> refs({int? studentId, int? enrollmentId}) {
    final out = <String, dynamic>{};
    if (studentId != null && studentId < 0) {
      out['student_ref'] = studentById(studentId)?['_ref'];
    }
    if (enrollmentId != null && enrollmentId < 0) {
      out['enrollment_ref'] = enrollment(enrollmentId)?['_ref'];
    }
    return out;
  }

  Map<String, dynamic>? classById(int classId) {
    for (final c in classes) {
      if (_int(c['class_id']) == classId) return c;
    }
    return null;
  }

  Map<String, dynamic>? categoryFee(Map<String, dynamic> klass, int classCategoryFeeId) {
    for (final f in (klass['category_fees'] as List? ?? const []).whereType<Map>()) {
      if (_int(f['class_category_fee_id']) == classCategoryFeeId) return Map<String, dynamic>.from(f);
    }
    return null;
  }

  String? gradeName(int gradeId) {
    for (final g in grades) {
      if (_int(g['id']) == gradeId) return g['grade_name']?.toString();
    }
    return null;
  }

  Map<String, dynamic>? scheduleFor(Map<String, dynamic> enrollment) {
    for (final s in schedules) {
      if (_int(s['student_class_id']) == _int(enrollment['student_class_id']) &&
          _int(s['class_category_fee_id']) == _int(enrollment['class_category_fee_id'])) {
        return s;
      }
    }
    return null;
  }

  /// Class details of an enrollment: today's schedule, or the class list.
  Map<String, dynamic> classInfo(Map<String, dynamic> enrollment) {
    final schedule = scheduleFor(enrollment);
    if (schedule != null) return schedule;

    final klass = classById(_int(enrollment['student_class_id']));
    if (klass == null) return const {};
    final fee = categoryFee(klass, _int(enrollment['class_category_fee_id']));
    return {
      'class_name': klass['class_name'],
      'grade': klass['grade_name'],
      'teacher': klass['teacher_name'],
      'teacher_name': klass['teacher_name'],
      'category': fee?['category_name'],
      'subject': '',
    };
  }

  List<Map<String, dynamic>> feeOptions(int classCategoryFeeId) {
    final all = json['fee_options'];
    if (all is Map && all[classCategoryFeeId.toString()] is List) {
      return (all[classCategoryFeeId.toString()] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    // a class that is not on today's schedule: its options from the class list
    for (final c in classes) {
      final fee = categoryFee(c, classCategoryFeeId);
      if (fee != null) return _list('fee_options', fee);
    }
    return const [];
  }

  /// The student's classes open for attendance now (Payment & Attendance Rules).
  List<OfflineOpenClass> openClasses(int studentId, DateTime now) {
    final open = <OfflineOpenClass>[];
    for (final e in enrollmentsOf(studentId)) {
      for (final s in schedules) {
        if (_int(s['student_class_id']) != _int(e['student_class_id']) ||
            _int(s['class_category_fee_id']) != _int(e['class_category_fee_id'])) {
          continue;
        }
        final from = DateTime.tryParse(s['scan_from']?.toString() ?? '')?.toLocal();
        final until = DateTime.tryParse(s['scan_until']?.toString() ?? '')?.toLocal();
        if (from != null && until != null && !now.isBefore(from) && !now.isAfter(until)) {
          open.add(OfflineOpenClass(s, e));
        }
      }
    }
    return open;
  }

  bool attendanceMarked(int studentId, int scheduleId) => queue.any((q) =>
      q['type'] == 'attendance' &&
      _int(q['student_id']) == studentId &&
      _int(q['schedule_id']) == scheduleId &&
      q['_status'] != 'failed');

  /// Paid on the server (pack) or on this phone (queue), for any enrollment
  /// of the same student + class + category (a fee option change makes a
  /// new enrollment).
  bool isMonthPaid(Map<String, dynamic> enrollment, String month) {
    final sameGroup = [
      ..._list('enrollments'),
      ..._localEnrollments,
    ].where((e) => _sameGroup(e, enrollment)).toList();

    for (final e in sameGroup) {
      if ((e['paid_months'] as List? ?? const []).map((m) => m.toString()).contains(month)) return true;
    }

    final ids = sameGroup.map((e) => _int(e['id'])).toSet();
    return queue.any((q) =>
        q['type'] == 'payment' &&
        ids.contains(_int(q['enrollment_id'])) &&
        q['payment_month'] == month &&
        q['_status'] != 'failed' &&
        q['_status'] != 'conflict');
  }

  /// A card given on this phone (not sent yet, or sent).
  bool cardUsedOnPhone(String code) {
    final wanted = code.trim().toUpperCase();
    return queue.any((q) {
      if (q['type'] != 'student' || q['_status'] == 'failed' || q['_status'] == 'conflict') return false;
      final form = q['student'];
      if (form is! Map) return false;
      return (form['temporary_qr_code'] ?? form['card_qr_code'] ?? '').toString().toUpperCase() == wanted;
    });
  }

  Map<String, dynamic>? card(String code) {
    final wanted = code.trim().toUpperCase();
    for (final c in cards) {
      if ((c['qr_code'] ?? '').toString().toUpperCase() == wanted) return c;
    }
    return null;
  }
}
