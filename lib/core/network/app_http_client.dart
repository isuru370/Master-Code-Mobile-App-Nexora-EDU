import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../navigation/app_navigator.dart';
import '../navigation/role_router.dart';
import '../storage/session_storage.dart';

/// The one HTTP client the whole app uses.
///
/// main() runs the app inside `http.runWithClient(...)`, so every
/// `http.get / post / put / patch / delete` call and every
/// `MultipartRequest.send()` in the datasources goes through here -
/// no datasource needs to change.
///
/// It adds:
///  - a timeout, so a dead Wi-Fi / server never leaves a spinner running
///    forever (the datasources get a normal `http.ClientException`)
///  - `Accept: application/json`, so Laravel answers errors as JSON
///  - one place that handles 401 (token expired / logged out elsewhere):
///    clear the session and go back to the sign-in screen
class AppHttpClient extends http.BaseClient {
  AppHttpClient({
    http.Client? inner,
    this.timeout = const Duration(seconds: 30),
    this.uploadTimeout = const Duration(seconds: 120),
  }) : _inner = inner ?? IOClient();

  final http.Client _inner;

  /// Normal API calls
  final Duration timeout;

  /// Photo uploads (MultipartRequest) can be slow on mobile data
  final Duration uploadTimeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.putIfAbsent('Accept', () => 'application/json');

    final limit = request is http.MultipartRequest ? uploadTimeout : timeout;

    final http.StreamedResponse response;

    try {
      response = await _inner.send(request).timeout(limit);
    } on TimeoutException {
      throw http.ClientException(
        'Server is not responding. Check the Wi-Fi / server and try again.',
        request.url,
      );
    }

    if (response.statusCode == 401 && _handles401(request.url)) {
      // Let the caller finish with its own error; the user is sent to
      // sign in at the same time.
      unawaited(SessionExpiredHandler.handle());
    }

    // An error page that is not JSON (502 from the proxy, maintenance page,
    // PHP fatal error, upload too large ...) would reach the datasources as
    // "FormatException: Unexpected character <!DOCTYPE html>". Replace it
    // with the JSON every datasource already understands.
    final contentType = response.headers['content-type'] ?? '';
    if (response.statusCode >= 400 && !contentType.contains('json')) {
      await response.stream.drain<void>();

      final body = utf8.encode(jsonEncode({
        'success': false,
        'status': false,
        'message': _errorPageMessage(response.statusCode),
        'data': null,
      }));

      return http.StreamedResponse(
        Stream.value(body),
        response.statusCode,
        contentLength: body.length,
        request: response.request,
        headers: {...response.headers, 'content-type': 'application/json'},
        reasonPhrase: response.reasonPhrase,
      );
    }

    return response;
  }

  static String _errorPageMessage(int status) {
    return switch (status) {
      413 => 'The file is too large to upload. Use a smaller photo.',
      404 => 'This feature was not found on the server ($status). The server or the app may need an update.',
      502 || 503 || 504 => 'The server is not available right now ($status). Please try again in a few minutes.',
      >= 500 => 'Server error ($status). Please try again, or contact the office if it keeps happening.',
      _ => 'Request failed ($status). Please try again.',
    };
  }

  /// 401 from these is not "session expired":
  ///  - /login  : wrong email or password
  ///  - /logout : already logged out
  ///  - /me     : the splash screen handles it itself
  static bool _handles401(Uri url) {
    final path = url.path;
    return !(path.endsWith('/login') ||
        path.endsWith('/logout') ||
        path.endsWith('/me'));
  }

  @override
  void close() => _inner.close();
}

/// Token is no longer valid -> clear the session, back to sign in (once).
class SessionExpiredHandler {
  SessionExpiredHandler._();

  static bool _running = false;

  static Future<void> handle() async {
    if (_running) return;

    // Not logged in (e.g. login screen) -> nothing to do
    if (!await SessionStorage.isLoggedIn()) return;

    _running = true;

    try {
      await SessionStorage.clear();

      AppNavigator.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        RoleRouter.signIn,
        (route) => false,
      );

      AppNavigator.showMessage('Session expired. Please login again.');
    } finally {
      // Several requests can fail together - handle them as one.
      Future<void>.delayed(const Duration(seconds: 3), () {
        _running = false;
      });
    }
  }
}
