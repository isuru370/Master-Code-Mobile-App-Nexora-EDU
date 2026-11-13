import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/session_storage.dart';

/// Teacher tools in the staff app: attendance, class day changes and own
/// payments. Each one is turned on by the institute (web: Settings > Teacher
/// App). Calls /api/v1/teacher/...
class TeacherToolsApi {
  const TeacherToolsApi();

  static String get _base => '${ApiConstants.apiUrl}/v1/teacher';

  /* ------------------------------ Features ------------------------------ */

  /// What the institute lets teachers do. An older server (404) = nothing.
  Future<TeacherToolsFeatures> features() async {
    try {
      final body = await _get('/features');
      return TeacherToolsFeatures.fromJson(jMap(body['data']));
    } on TeacherToolsException catch (e) {
      if (e.statusCode == 404) return const TeacherToolsFeatures();
      rethrow;
    }
  }

  /* ----------------------------- Attendance ----------------------------- */

  Future<List<TeacherDay>> todayClasses() async {
    final body = await _get('/attendance/today');
    return jList(jMap(body['data'])['classes']).map(TeacherDay.fromJson).toList();
  }

  Future<List<TeacherDayStudent>> dayStudents(TeacherDay day) async {
    final body = await _get('/attendance/${day.type}/${day.id}/students');
    return jList(jMap(body['data'])['students']).map(TeacherDayStudent.fromJson).toList();
  }

  /// Returns the server message, e.g. "2 marked, 0 already marked."
  Future<MarkResult> mark(TeacherDay day, List<int> studentIds) async {
    final body = await _send('POST', '/attendance/${day.type}/${day.id}/mark', {'student_ids': studentIds});
    final data = jMap(body['data']);

    return MarkResult(
      message: jStr(body['message']),
      marked: jInt(data['marked']),
      already: jInt(data['already']),
      failed: jMap(data['failed']).values.map((v) => v.toString()).toList(),
    );
  }

  /// One QR scan. A refused scan (not in this class...) comes back with ok = false.
  Future<ScanResult> scan(TeacherDay day, String code) async {
    try {
      final body = await _send('POST', '/attendance/${day.type}/${day.id}/scan', {'qr_code': code});
      final data = jMap(body['data']);

      return ScanResult(
        ok: true,
        already: jBool(data['already_marked']),
        message: jStr(body['message']),
        studentName: jStr(jMap(data['student'])['name']),
      );
    } on TeacherToolsException catch (e) {
      if (e.statusCode == 422) {
        return ScanResult(ok: false, already: false, message: e.message, studentName: '');
      }
      rethrow;
    }
  }

  /* ------------------------------ Schedule ------------------------------ */

  Future<ScheduleOverview> schedule() async {
    final body = await _get('/schedule');
    return ScheduleOverview.fromJson(jMap(body['data']));
  }

  Future<ScheduleOptions> scheduleOptions() async {
    final body = await _get('/schedule/options');
    return ScheduleOptions.fromJson(jMap(body['data']));
  }

  /// [kind] class | course, [action] create | update | cancel.
  /// [id]: the class / course for create, the class day for update / cancel.
  Future<RequestResult> requestChange({
    required String kind,
    required String action,
    required int id,
    int? categoryFeeId,
    String? date,
    String? startTime,
    String? endTime,
    int? hallId,
    String? reason,
    String? note,
  }) async {
    final body = await _send('POST', '/schedule/requests', {
      'kind': kind,
      'action': action,
      'id': id,
      if (categoryFeeId != null) 'class_category_fee_id': categoryFeeId,
      if (date != null) 'date': date,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (hallId != null) 'class_hall_id': hallId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    final data = jMap(body['data']);

    return RequestResult(
      message: jStr(body['message']),
      applied: jStr(jMap(data['request'])['status']) == 'approved',
    );
  }

  Future<void> withdraw(int requestId) async {
    await _send('DELETE', '/schedule/requests/$requestId', null);
  }

  /* ------------------------------ Payments ------------------------------ */

  Future<List<IdName>> paymentBranches() async {
    final body = await _get('/payments/branches');
    return jList(jMap(body['data'])['branches']).map((b) => IdName(jInt(b['id']), jStr(b['name']))).toList();
  }

  Future<Map<String, dynamic>> paymentMonth({int? branchId, required int year, required int month}) async {
    return jMap((await _get('/payments/month${_q(branchId, year, month)}'))['data']);
  }

  Future<Map<String, dynamic>> paymentDeductions({int? branchId, required int year, required int month}) async {
    return jMap((await _get('/payments/deductions${_q(branchId, year, month)}'))['data']);
  }

  Future<Map<String, dynamic>> paymentHistory({int? branchId}) async {
    return jMap((await _get('/payments/history${branchId == null ? '' : '?branch_id=$branchId'}'))['data']);
  }

  /// [basis] fee-month (fee of that month) or paid-date (collected that month)
  Future<Map<String, dynamic>> paymentStudents({int? branchId, required int year, required int month, String basis = 'fee-month'}) async {
    return jMap((await _get('/payments/students${_q(branchId, year, month)}&basis=$basis'))['data']);
  }

  Future<Map<String, dynamic>> paymentCourses() async {
    return jMap((await _get('/payments/courses'))['data']);
  }

  String _q(int? branchId, int year, int month) =>
      '?year=$year&month=$month${branchId == null ? '' : '&branch_id=$branchId'}';

  /* ------------------------------- HTTP --------------------------------- */

  Future<Map<String, dynamic>> _get(String path) => _send('GET', path, null);

  Future<Map<String, dynamic>> _send(String method, String path, Map<String, dynamic>? payload) async {
    final uri = Uri.parse('$_base$path');
    final headers = ApiConstants.headers(token: await SessionStorage.getToken());
    final http.Response response;

    try {
      final Future<http.Response> request = switch (method) {
        'POST' => http.post(uri, headers: headers, body: jsonEncode(payload ?? {})),
        'DELETE' => http.delete(uri, headers: headers),
        _ => http.get(uri, headers: headers),
      };
      response = await request.timeout(const Duration(seconds: 30));
    } on http.ClientException {
      throw const TeacherToolsException('No connection. Check the internet and try again.');
    } on Exception {
      throw const TeacherToolsException('No connection. Check the internet and try again.');
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      body = <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        throw TeacherToolsException(first.first.toString(), statusCode: response.statusCode);
      }
    }

    final message = jStr(body['message']);

    throw TeacherToolsException(
      switch (response.statusCode) {
        403 => message.isNotEmpty ? message : 'Your institute has not turned this on for teachers.',
        404 => message.isNotEmpty && !message.startsWith('The route') ? message : 'Not found. The server may need an update.',
        _ => message.isNotEmpty && response.statusCode < 500 ? message : 'Something went wrong. Please try again.',
      },
      statusCode: response.statusCode,
    );
  }
}

class TeacherToolsException implements Exception {
  final String message;
  final int? statusCode;

  const TeacherToolsException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/* ------------------------------- JSON read -------------------------------- */

String jStr(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

int jInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0);

int? jIntOrNull(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()));

double jDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

bool jBool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

Map<String, dynamic> jMap(dynamic v) => v is Map<String, dynamic> ? v : (v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{});

List<Map<String, dynamic>> jList(dynamic v) => v is List ? v.map(jMap).toList() : <Map<String, dynamic>>[];

/* -------------------------------- Models ---------------------------------- */

class TeacherToolsFeatures {
  final bool attendance;
  final bool schedule;
  final bool scheduleAuto;
  final bool payments;
  final bool courses;

  const TeacherToolsFeatures({
    this.attendance = false,
    this.schedule = false,
    this.scheduleAuto = false,
    this.payments = false,
    this.courses = false,
  });

  bool get any => attendance || schedule || payments;

  factory TeacherToolsFeatures.fromJson(Map<String, dynamic> j) => TeacherToolsFeatures(
        attendance: jBool(j['attendance']),
        schedule: jBool(j['schedule']),
        scheduleAuto: jBool(j['schedule_auto']),
        payments: jBool(j['payments']),
        courses: jBool(j['courses']),
      );
}

class IdName {
  final int id;
  final String name;

  const IdName(this.id, this.name);
}

/// A class day (class schedule or course session).
class TeacherDay {
  final String type; // class | course
  final int id;
  final int classId;
  final String title;
  final String category;
  final int? categoryFeeId;
  final String date;
  final String startTime;
  final String endTime;
  final int? hallId;
  final String hall;
  final String status;
  final int present;
  final int enrolled;
  final bool canChange;
  final bool canCancel;
  final bool pendingRequest;
  final String cancelReason;

  const TeacherDay({
    required this.type,
    required this.id,
    required this.classId,
    required this.title,
    required this.category,
    required this.categoryFeeId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.hallId,
    required this.hall,
    required this.status,
    required this.present,
    required this.enrolled,
    required this.canChange,
    required this.canCancel,
    required this.pendingRequest,
    required this.cancelReason,
  });

  bool get isCourse => type == 'course';

  factory TeacherDay.fromJson(Map<String, dynamic> j) => TeacherDay(
        type: jStr(j['type'], 'class'),
        id: jInt(j['id']),
        classId: jInt(j['class_id']),
        title: jStr(j['title']),
        category: jStr(j['category']),
        categoryFeeId: jIntOrNull(j['class_category_fee_id']),
        date: jStr(j['date']),
        startTime: jStr(j['start_time']),
        endTime: jStr(j['end_time']),
        hallId: jIntOrNull(j['hall_id']),
        hall: jStr(j['hall']),
        status: jStr(j['status']),
        present: jInt(j['present']),
        enrolled: jInt(j['enrolled']),
        canChange: jBool(j['can_change']),
        canCancel: jBool(j['can_cancel']),
        pendingRequest: jBool(j['pending_request']),
        cancelReason: jStr(j['cancel_reason']),
      );
}

class TeacherDayStudent {
  final int id;
  final String code;
  final String name;
  final bool present;

  const TeacherDayStudent({required this.id, required this.code, required this.name, required this.present});

  factory TeacherDayStudent.fromJson(Map<String, dynamic> j) => TeacherDayStudent(
        id: jInt(j['student_id']),
        code: jStr(j['student_code']),
        name: jStr(j['name']),
        present: jBool(j['present']),
      );
}

class MarkResult {
  final String message;
  final int marked;
  final int already;
  final List<String> failed;

  const MarkResult({required this.message, required this.marked, required this.already, required this.failed});
}

class ScanResult {
  final bool ok;
  final bool already;
  final String message;
  final String studentName;

  const ScanResult({required this.ok, required this.already, required this.message, required this.studentName});
}

class RequestResult {
  final String message;
  final bool applied;

  const RequestResult({required this.message, required this.applied});
}

class ScheduleRequest {
  final int id;
  final String kind;
  final String action;
  final String title;
  final Map<String, dynamic> details;
  final String status;
  final String error;
  final String reviewNote;
  final String createdAt;

  const ScheduleRequest({
    required this.id,
    required this.kind,
    required this.action,
    required this.title,
    required this.details,
    required this.status,
    required this.error,
    required this.reviewNote,
    required this.createdAt,
  });

  factory ScheduleRequest.fromJson(Map<String, dynamic> j) => ScheduleRequest(
        id: jInt(j['id']),
        kind: jStr(j['kind']),
        action: jStr(j['action']),
        title: jStr(j['title']),
        details: jMap(j['details']),
        status: jStr(j['status']),
        error: jStr(j['error']),
        reviewNote: jStr(j['review_note']),
        createdAt: jStr(j['created_at']),
      );
}

class ScheduleOverview {
  final bool autoApply;
  final List<TeacherDay> days;
  final List<ScheduleRequest> requests;

  const ScheduleOverview({required this.autoApply, required this.days, required this.requests});

  factory ScheduleOverview.fromJson(Map<String, dynamic> j) => ScheduleOverview(
        autoApply: jBool(j['auto_apply']),
        days: jList(j['schedules']).map(TeacherDay.fromJson).toList(),
        requests: jList(j['requests']).map(ScheduleRequest.fromJson).toList(),
      );
}

class OptionClass {
  final int id;
  final String name;
  final bool isCourse;
  final List<IdName> categories; // id = class_category_fee_id
  final List<IdName> halls;

  const OptionClass({required this.id, required this.name, required this.isCourse, required this.categories, required this.halls});
}

class ScheduleOptions {
  final List<OptionClass> classes;
  final List<OptionClass> courses;

  const ScheduleOptions({required this.classes, required this.courses});

  List<IdName> hallsFor(TeacherDay day) {
    final list = day.isCourse ? courses : classes;
    for (final c in list) {
      if (c.id == day.classId) return c.halls;
    }
    return const [];
  }

  factory ScheduleOptions.fromJson(Map<String, dynamic> j) {
    List<IdName> halls(dynamic v) => jList(v).map((h) => IdName(jInt(h['id']), jStr(h['name']))).toList();

    return ScheduleOptions(
      classes: jList(j['classes'])
          .map((c) => OptionClass(
                id: jInt(c['id']),
                name: jStr(c['name']),
                isCourse: false,
                categories: jList(c['categories']).map((f) => IdName(jInt(f['class_category_fee_id']), jStr(f['name']))).toList(),
                halls: halls(c['halls']),
              ))
          .toList(),
      courses: jList(j['courses'])
          .map((c) => OptionClass(id: jInt(c['id']), name: jStr(c['name']), isCourse: true, categories: const [], halls: halls(c['halls'])))
          .toList(),
    );
  }
}
