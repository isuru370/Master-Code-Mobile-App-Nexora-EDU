import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../core/offline/offline_engine.dart';
import '../../../../../core/offline/offline_store.dart';
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

    final cacheKey = 'dashboard_${branchId ?? 'all'}';

    try {
      response = await http
          .get(uri, headers: ApiConstants.headers(token: token))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      if (!OfflineEngine.isNetworkError(e)) rethrow;

      // offline: the last dashboard on this phone (numbers "as of" then)
      final cached = await OfflineStore.readCache(cacheKey);
      if (cached != null) {
        return MobileDashboardResponseModel.fromJson(cached.body, cachedAt: cached.savedAt);
      }
      throw NetworkException(e is TimeoutException
          ? 'Server is not responding. Please try again.'
          : 'Cannot connect to the server. Check your internet.');
    }

    final body = _decode(response.body);
    final message = body['message']?.toString();

    if (response.statusCode == 200) {
      await OfflineStore.writeCache(cacheKey, _withoutPhones(body) as Map<String, dynamic>);
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

  /// No phone numbers kept on the phone (offline data rule).
  static dynamic _withoutPhones(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          if (!const {'guardian_mobile', 'mobile', 'phone', 'whatsapp_mobile'}.contains(entry.key))
            entry.key.toString(): _withoutPhones(entry.value),
      };
    }
    if (value is List) return value.map(_withoutPhones).toList();
    return value;
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