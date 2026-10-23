import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/storage/session_storage.dart';
import '../model/scan_attendance_new/attendance_class_choice_model.dart';
import '../model/scan_attendance_new/scan_attendance_request_model.dart';
import '../model/scan_attendance_new/scan_attendance_response_model.dart';

class ScanAttendanceRemoteDatasource {
  Future<ScanAttendanceResponseModel> readAttendance({
    required ScanAttendanceRequestModel requestModel,
  }) async {
    final token = await SessionStorage.getToken();

    final response = await http.post(
      Uri.parse('${ApiConstants.apiUrl}/new-attendance/scan'),
      headers: ApiConstants.headers(token: token),
      body: jsonEncode(requestModel.toJson()),
    );

    debugPrint('ATTENDANCE STATUS: ${response.statusCode}');

    debugPrint('ATTENDANCE BODY: ${response.body}');

    dynamic decodedBody;

    try {
      decodedBody = jsonDecode(response.body);
    } catch (e) {
      throw Exception('Invalid response received from attendance server.');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ScanAttendanceResponseModel.fromJson(
        decodedBody as Map<String, dynamic>,
      );
    }

    // 409: the student has more than one class open now - nothing was
    // marked, the user must pick the class.
    if (response.statusCode == 409 && decodedBody is Map<String, dynamic>) {
      final data = decodedBody['data'];

      if (data is Map<String, dynamic> && data['requires_class_selection'] == true) {
        final student = data['student'] is Map<String, dynamic>
            ? data['student'] as Map<String, dynamic>
            : const <String, dynamic>{};

        throw ClassSelectionRequiredException(
          message: (decodedBody['message'] ?? 'Choose the class.').toString(),
          studentName: (student['initial_name'] ?? student['full_name'] ?? '').toString(),
          studentCode: (student['custom_id'] ?? requestModel.code).toString(),
          classes: (data['classes'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(AttendanceClassChoiceModel.fromJson)
              .where((c) => c.scheduleId > 0)
              .toList(),
        );
      }
    }

    final message = decodedBody is Map<String, dynamic>
        ? decodedBody['message']?.toString()
        : null;

    throw Exception(message ?? 'Failed to scan attendance.');
  }
}
