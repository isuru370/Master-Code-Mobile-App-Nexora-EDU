import 'dart:async';

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

    return response;
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
