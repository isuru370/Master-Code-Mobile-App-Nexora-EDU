import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/storage/session_storage.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';

class AuthRemoteDataSource {
  /// Without a timeout the login spinner runs forever when the
  /// phone cannot reach the server (wrong IP, server on 127.0.0.1 ...).
  static const Duration _loginTimeout = Duration(seconds: 20);
  static const Duration _meTimeout = Duration(seconds: 10);
  static const Duration _logoutTimeout = Duration(seconds: 8);

  /*
  |--------------------------------------------------------------------------
  | POST /api/login
  |--------------------------------------------------------------------------
  */
  Future<LoginResponseModel> login(LoginRequestModel request) async {
    debugPrint('LOGIN URL: ${ApiConstants.login}');

    final http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(ApiConstants.login),
            headers: ApiConstants.headers(),
            body: jsonEncode(request.toJson()),
          )
          .timeout(_loginTimeout);
    } on TimeoutException {
      throw const NetworkException(
        'Server is not responding. Check the server IP / Wi-Fi and try again.',
      );
    } on SocketException {
      throw const NetworkException(
        'Cannot connect to the server. Check the server IP / Wi-Fi.',
      );
    } on http.ClientException {
      throw const NetworkException(
        'Cannot connect to the server. Check the server IP / Wi-Fi.',
      );
    }

    debugPrint('LOGIN RESPONSE CODE: ${response.statusCode}');
    debugPrint('LOGIN RESPONSE BODY: ${response.body}');

    final data = _decode(response.body);
    final serverMessage = (data['message'] ?? 'Something went wrong')
        .toString();

    if (response.statusCode == 200) {
      final LoginResponseModel result;

      try {
        result = LoginResponseModel.fromJson(data);
      } catch (e) {
        debugPrint('LOGIN PARSE ERROR: $e');
        throw const ServerException('Invalid server response', 500);
      }

      // token + user + role + branches
      await SessionStorage.saveSession(result);

      return result;
    }

    if (response.statusCode == 401) {
      throw UnauthorizedException(serverMessage);
    }

    if (response.statusCode == 429) {
      throw const ServerException(
        'Too many login attempts. Please wait 1 minute and try again.',
        429,
      );
    }

    // 403 (inactive account / no branch ...), 422 (validation), 500
    throw ServerException(serverMessage, response.statusCode);
  }

  /*
  |--------------------------------------------------------------------------
  | GET /api/me
  |--------------------------------------------------------------------------
  | Checks the saved token and refreshes the saved role / branches. Throws:
  |   UnauthorizedException - token expired or logged out (401)
  |   ServerException       - account / role inactive (403) or server error
  |   NetworkException      - no internet / server not reachable
  */
  Future<LoginResponseModel> me() async {
    final token = await SessionStorage.getToken();

    if (token == null || token.trim().isEmpty) {
      throw const UnauthorizedException('Not logged in');
    }

    final http.Response response;

    try {
      response = await http
          .get(
            Uri.parse(ApiConstants.me),
            headers: ApiConstants.headers(token: token),
          )
          .timeout(_meTimeout);
    } on TimeoutException {
      throw const NetworkException('Server is not responding');
    } on SocketException {
      throw const NetworkException('No internet connection');
    } on http.ClientException {
      throw const NetworkException('No internet connection');
    }

    debugPrint('ME RESPONSE CODE: ${response.statusCode}');

    final data = _decode(response.body);
    final serverMessage = (data['message'] ?? 'Something went wrong')
        .toString();

    if (response.statusCode == 200) {
      final result = LoginResponseModel.fromJson(data);

      // /me has no token - the saved token is kept
      await SessionStorage.saveSession(result);

      return result;
    }

    if (response.statusCode == 401) {
      throw UnauthorizedException(serverMessage);
    }

    throw ServerException(serverMessage, response.statusCode);
  }

  /*
  |--------------------------------------------------------------------------
  | POST /api/logout
  |--------------------------------------------------------------------------
  | Always clears the saved session, even when the server cannot be reached.
  */
  Future<void> logout() async {
    final token = await SessionStorage.getToken();

    try {
      if (token != null && token.isNotEmpty) {
        await http
            .post(
              Uri.parse(ApiConstants.logout),
              headers: ApiConstants.headers(token: token),
            )
            .timeout(_logoutTimeout);
      }
    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');
    } finally {
      await SessionStorage.clear();
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}