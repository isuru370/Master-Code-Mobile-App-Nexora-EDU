import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import 'server_config.dart';

/// This institute's name, tagline and logo (splash, login, printed
/// receipts), from GET /api/institute - the server .env INSTITUTE_*.
///
/// Saved on the phone, so the next start shows them straight away and
/// works offline. Until the first answer: the build's APP_NAME.
class InstituteInfo {
  InstituteInfo._();

  /// Name on the phone's home screen, set when building:
  ///   flutter build apk --dart-define=APP_NAME=MihisaraEdu
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'NexoraEdu',
  );

  static const String _key = 'institute_info';
  static const String _logoFile = 'institute_logo.img';
  static const String defaultLogoAsset = 'assets/logo/logo.png';

  static String _name = '';
  static String _shortName = '';
  static String _tagline = '';
  static String _logoUrl = '';
  static String? _logoPath;

  /// Changes when new details arrive (screens rebuild with it).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// "Mihisara Education Institute" (or the build's APP_NAME until known)
  static String get name => _name.isNotEmpty ? _name : appName;

  /// "MihisaraEdu"
  static String get shortName => _shortName.isNotEmpty ? _shortName : appName;

  static String get tagline => _tagline;

  /// Downloaded logo, or the logo inside the app.
  static ImageProvider get logo {
    final path = _logoPath;
    if (path != null && File(path).existsSync()) {
      return FileImage(File(path));
    }
    return const AssetImage(defaultLogoAsset);
  }

  /// The details saved on the phone (no network).
  static Future<void> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;

      final data = jsonDecode(raw);
      if (data is! Map) return;

      _apply(data);
      _logoPath = data['logo_path']?.toString();
      changes.value++;
    } catch (_) {
      // broken saved data: keep the defaults
    }
  }

  /// Ask the server; keeps the saved details when it cannot be reached.
  static Future<void> refresh() async {
    // Before the institute QR is scanned there is no server to ask
    if (!ServerConfig.isConfigured) return;

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConstants.apiUrl}/institute'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final body = jsonDecode(response.body);
      final data = body is Map ? body['data'] : null;
      if (data is! Map) return;

      final newLogoUrl = data['logo_url']?.toString() ?? '';
      final logoChanged = newLogoUrl != _logoUrl || _logoPath == null;

      _apply(data);

      if (newLogoUrl.isEmpty) {
        _logoPath = null;
      } else if (logoChanged) {
        _logoPath = await _downloadLogo(newLogoUrl) ?? _logoPath;
      }

      await _save();
      changes.value++;
    } catch (e) {
      if (kDebugMode) debugPrint('INSTITUTE INFO ERROR: $e');
    }
  }

  /// Details from the institute QR check (POST /api/app-setup/verify):
  /// shown and saved straight away, logo downloaded.
  static Future<void> applyFromSetup(Map data) async {
    final newLogoUrl = data['logo_url']?.toString() ?? '';

    _apply(data);
    _logoPath = newLogoUrl.isEmpty ? null : await _downloadLogo(newLogoUrl);

    await _save();
    changes.value++;
  }

  /// "Change institute": forget this institute's name and logo.
  static Future<void> clearSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);

      final path = _logoPath;
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) {
          PaintingBinding.instance.imageCache.evict(FileImage(file));
          await file.delete();
        }
      }
    } catch (_) {
      // nothing saved / file already gone
    }

    _name = '';
    _shortName = '';
    _tagline = '';
    _logoUrl = '';
    _logoPath = null;
    changes.value++;
  }

  static void _apply(Map data) {
    _name = data['name']?.toString().trim() ?? '';
    _shortName = data['short_name']?.toString().trim() ?? '';
    _tagline = data['tagline']?.toString().trim() ?? '';
    _logoUrl = data['logo_url']?.toString() ?? '';
  }

  static Future<String?> _downloadLogo(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      final type = response.headers['content-type'] ?? '';
      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty ||
          !type.startsWith('image/')) {
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_logoFile');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      // the same path is reused: forget the old picture
      PaintingBinding.instance.imageCache.evict(FileImage(file));

      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'name': _name,
        'short_name': _shortName,
        'tagline': _tagline,
        'logo_url': _logoUrl,
        'logo_path': _logoPath,
      }),
    );
  }

  /// For tests.
  @visibleForTesting
  static void setForTest({String name = '', String shortName = '', String tagline = ''}) {
    _name = name;
    _shortName = shortName;
    _tagline = tagline;
    _logoUrl = '';
    _logoPath = null;
  }
}
