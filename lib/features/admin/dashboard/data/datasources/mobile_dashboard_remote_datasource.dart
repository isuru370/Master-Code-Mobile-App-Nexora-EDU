import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../core/storage/session_storage.dart';
import '../models/mobile_dashboard_response_model.dart';

class MobileDashboardRemoteDataSource {
  /// GET /api/mobile-dashboard?branch_id=
  ///
  /// branch_id = the branch picked in the app (SessionStorage).
  /// No branch picked -> all branches the user can access.
  Future<MobileDashboardResponseModel> getDashboard() async {
    final token = await SessionStorage.getToken();
    final branchId = await SessionStorage.getSelectedBranchId();

    final uri = Uri.parse('${ApiConstants.apiUrl}/mobile-dashboard').replace(
      queryParameters: branchId == null ? null : {'branch_id': '$branchId'},
    );

    final http.Response response;

    try {
      response = await http
          .get(uri, headers: ApiConstants.headers(token: token))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const NetworkException('Server is not responding. Please try again.');
    } on http.ClientException {
      throw const NetworkException('Cannot connect to the server. Check your internet.');
    }

    final body = _decode(response.body);
    final message = body['message']?.toString();

    if (response.statusCode == 200) {
      return MobileDashboardResponseModel.fromJson(body);
    }

    if (response.statusCode == 401) {
      throw UnauthorizedException(message ?? 'Session expired. Please login again.');
    }

    // 403: no access to that branch / role cannot use the dashboard
    throw ServerException(
      message ?? 'Failed to load dashboard',
      response.statusCode,
    );
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final data = jsonDecode(body);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}