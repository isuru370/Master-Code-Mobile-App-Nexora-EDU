import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/session_storage.dart';
import 'course_models.dart';

/// Calls /api/courses/... (staff app). Throws [CourseApiException] with the
/// server's message (or the first validation error) when something fails.
class CourseApi {
  const CourseApi();

  static String get _base => '${ApiConstants.apiUrl}/courses';

  /* ----------------------------- Attendance ----------------------------- */

  /// Class days on [date] (yyyy-MM-dd), default today.
  Future<List<CourseSessionItem>> sessions({String? date}) async {
    final query = date == null ? '' : '?date=$date';
    final body = await _get('$_base/sessions$query');
    final sessions = _data(body)['sessions'];

    return sessions is List
        ? sessions
            .whereType<Map<String, dynamic>>()
            .map(CourseSessionItem.fromJson)
            .toList()
        : <CourseSessionItem>[];
  }

  Future<CourseAttendanceResult> markAttendance({
    required int sessionId,
    required String code,
    bool scanned = true,
  }) async {
    final body = await _post('$_base/sessions/$sessionId/attendance', {
      'code': code.trim(),
      'mark_method': scanned ? 'qr_mobile' : 'manual_mobile',
    });

    return CourseAttendanceResult.fromJson(_data(body), _message(body));
  }

  Future<CourseSessionReport> report(int sessionId) async {
    final body = await _get('$_base/sessions/$sessionId/report');

    return CourseSessionReport.fromJson(_data(body));
  }

  /* ------------------------------ Payment ------------------------------- */

  Future<CourseStudentResult> student(String code) async {
    final body = await _post('$_base/student', {'code': code.trim()});

    return CourseStudentResult.fromJson(_data(body));
  }

  Future<CourseEnrollmentItem> enroll({
    required int courseId,
    required String code,
    required String paymentPlan,
    double? specialFee,
    String? specialFeeReason,
  }) async {
    final body = await _post('$_base/$courseId/enroll', {
      'code': code.trim(),
      'payment_plan': paymentPlan,
      if (specialFee != null) 'special_fee': specialFee,
      if (specialFee != null) 'special_fee_reason': specialFeeReason,
    });

    return CourseEnrollmentItem.fromJson(_map(_data(body)['enrollment']));
  }

  Future<CourseReceipt> pay({
    required int enrollmentId,
    required double amount,
    required String paymentMethod,
    bool scanned = true,
  }) async {
    final body = await _post('$_base/enrollments/$enrollmentId/pay', {
      'amount': amount,
      'payment_method': paymentMethod,
      'mark_method': scanned ? 'qr_mobile' : 'manual_mobile',
    });

    return CourseReceipt.fromJson(_map(_data(body)['receipt']));
  }

  Future<CourseReceipt> receipt(int paymentId) async {
    final body = await _get('$_base/payments/$paymentId/receipt');

    return CourseReceipt.fromJson(_map(_data(body)['receipt']));
  }

  /* ------------------------------ Helpers ------------------------------- */

  Future<Map<String, dynamic>> _get(String url) async {
    final token = await SessionStorage.getToken();

    return _handle(
      () => http.get(Uri.parse(url), headers: ApiConstants.headers(token: token)),
    );
  }

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> data) async {
    final token = await SessionStorage.getToken();

    return _handle(
      () => http.post(
        Uri.parse(url),
        headers: ApiConstants.headers(token: token),
        body: jsonEncode(data),
      ),
    );
  }

  Future<Map<String, dynamic>> _handle(Future<http.Response> Function() call) async {
    final http.Response response;

    try {
      response = await call();
    } on http.ClientException catch (e) {
      throw CourseApiException(e.message);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const CourseApiException('The server sent an unexpected response. Please try again.');
    }

    final body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (response.statusCode == 404) {
      throw CourseApiException(
        _message(body).isNotEmpty && _message(body) != 'Not Found'
            ? _message(body)
            : 'Not found. Courses may be switched off for this institute.',
        statusCode: 404,
      );
    }

    // 422: show the first validation error ("No student found for ...")
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        throw CourseApiException(first.first.toString(), statusCode: response.statusCode);
      }
    }

    throw CourseApiException(
      _message(body).isNotEmpty ? _message(body) : 'Something went wrong. Please try again.',
      statusCode: response.statusCode,
    );
  }

  static Map<String, dynamic> _data(Map<String, dynamic> body) => _map(body['data']);

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  static String _message(Map<String, dynamic> body) => body['message']?.toString() ?? '';
}

class CourseApiException implements Exception {
  final String message;
  final int? statusCode;

  const CourseApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
