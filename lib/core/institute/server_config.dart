import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Which institute server this app talks to.
///
/// One app for every institute: on first start the user scans the
/// "Staff App QR" from the institute's web page (Admin > Staff App QR).
/// The QR holds `https://<institute>.nexorait.lk/app-setup?key=<secret>`.
///
///  1. [parseQr]  only accepts https *.nexorait.lk addresses (in debug
///                builds also a local test server).
///  2. [verify]   sends the key to that server; it must answer "valid".
///  3. [save]     keeps the address on the phone; then the normal login.
///
/// A build made with --dart-define=API_BASE_URL=... (the old way, one build
/// per institute) always uses that address and never asks for a QR.
class ServerConfig {
  ServerConfig._();

  static const String _builtUrl = String.fromEnvironment('API_BASE_URL');

  /// True for a build made for one institute (--dart-define=API_BASE_URL).
  static const bool isBuiltForInstitute = bool.hasEnvironment('API_BASE_URL');

  static const String _prefsKey = 'server_base_url';

  static String? _savedUrl;

  /// "https://savidyaedu.nexorait.lk" (no trailing slash), or '' before setup.
  static String get baseUrl =>
      isBuiltForInstitute ? _trimSlash(_builtUrl) : (_savedUrl ?? '');

  static bool get isConfigured => baseUrl.isNotEmpty;

  /// Read the saved address (call once in main, before the app starts).
  static Future<void> load() async {
    if (isBuiltForInstitute) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _savedUrl = (saved == null || saved.trim().isEmpty) ? null : _trimSlash(saved.trim());
    } catch (_) {
      _savedUrl = null;
    }
  }

  static Future<void> save(String baseUrl) async {
    final url = _trimSlash(baseUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, url);
    _savedUrl = url;
  }

  /// "Change institute": forget the address (the login is cleared separately).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _savedUrl = null;
  }

  /// Read and check the scanned text. Throws [InstituteSetupException]
  /// with a message for the user when it is not a valid institute QR.
  static InstituteQr parseQr(String raw, {bool allowLocal = kDebugMode}) {
    final uri = Uri.tryParse(raw.trim());

    if (uri == null || !uri.hasScheme || uri.host.isEmpty || uri.path != '/app-setup') {
      throw const InstituteSetupException(
        'This is not an institute QR code. Scan the QR from Staff App QR on the institute website.',
      );
    }

    final key = uri.queryParameters['key'] ?? '';
    if (!RegExp(r'^[A-Za-z0-9]{40}$').hasMatch(key)) {
      throw const InstituteSetupException(
        'This QR code is not complete. Ask your institute admin for the current QR.',
      );
    }

    final host = uri.host.toLowerCase();
    final isNexoraServer = uri.scheme == 'https' &&
        !uri.hasPort &&
        uri.userInfo.isEmpty &&
        (host == 'nexorait.lk' || host.endsWith('.nexorait.lk'));

    final isLocalTest = allowLocal && (uri.scheme == 'http' || uri.scheme == 'https');

    if (!isNexoraServer && !isLocalTest) {
      throw const InstituteSetupException(
        'This QR code is not from a Nexora EDU server. Only scan the QR from your institute.',
      );
    }

    final port = uri.hasPort ? ':${uri.port}' : '';

    return InstituteQr(baseUrl: '${uri.scheme}://$host$port', key: key);
  }

  /// Ask the scanned server whether the key is valid. Returns the institute
  /// details (name, short_name, tagline, logo_url, api_base_url).
  static Future<Map<String, dynamic>> verify(InstituteQr qr, {http.Client? client}) async {
    final http.Response response;

    try {
      final uri = Uri.parse('${qr.baseUrl}/api/app-setup/verify');
      const headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
      };
      final body = jsonEncode({'key': qr.key});

      response = await (client != null
              ? client.post(uri, headers: headers, body: body)
              : http.post(uri, headers: headers, body: body))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const InstituteSetupException(
        'The institute server did not answer. Check the internet connection and try again.',
      );
    } catch (_) {
      // no internet, DNS, TLS, ... (AppHttpClient may wrap these)
      throw const InstituteSetupException(
        'Cannot reach the institute server. Check the internet connection and try again.',
      );
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }

    if (response.statusCode == 429) {
      throw const InstituteSetupException('Too many tries. Wait a minute and scan again.');
    }

    if (response.statusCode == 422) {
      throw InstituteSetupException(
        body?['message']?.toString() ??
            'Invalid QR code. Ask your institute admin for the current QR.',
      );
    }

    final data = body?['data'];

    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      throw InstituteSetupException(
        'The institute server could not check this QR code (error ${response.statusCode}).',
      );
    }

    // The server must say it is the same address that was scanned
    final serverUrl = _trimSlash(data['api_base_url']?.toString() ?? '').toLowerCase();
    if (serverUrl != qr.baseUrl.toLowerCase()) {
      throw const InstituteSetupException(
        'This QR code does not match its server. Ask your institute admin for the current QR.',
      );
    }

    return data;
  }

  static String _trimSlash(String url) => url.replaceAll(RegExp(r'/+$'), '');

  @visibleForTesting
  static void setSavedForTest(String? url) => _savedUrl = url;
}

/// A scanned and checked (but not yet verified) institute QR.
class InstituteQr {
  const InstituteQr({required this.baseUrl, required this.key});

  /// "https://savidyaedu.nexorait.lk"
  final String baseUrl;

  /// The 40-character setup key.
  final String key;
}

class InstituteSetupException implements Exception {
  const InstituteSetupException(this.message);

  final String message;

  @override
  String toString() => message;
}
