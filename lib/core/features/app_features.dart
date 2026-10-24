import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../storage/session_storage.dart';

/// Optional features switched on for this institute (e.g. "courses").
///
/// Read from GET /api/features and kept on the phone, so the menus show
/// straight away next time. An institute server that does not know the
/// endpoint yet simply has no optional features.
class AppFeatures {
  AppFeatures._();

  static const String _key = 'app_features';

  static Map<String, bool> _features = const {};

  /// Courses section (Course Attendance / Course Payment)
  static bool get courses => _features['courses'] == true;

  static bool isOn(String key) => _features[key] == true;

  /// The list saved on the phone (no network).
  static Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _features = _decode(prefs.getString(_key));
  }

  /// Ask the server; keeps the saved list when the server cannot be reached.
  static Future<void> refresh() async {
    try {
      final token = await SessionStorage.getToken();
      final response = await http.get(
        Uri.parse('${ApiConstants.apiUrl}/features'),
        headers: ApiConstants.headers(token: token),
      );

      debugPrint('APP FEATURES: ${response.statusCode} ${response.body}');

      if (response.statusCode == 404) {
        await _save(const {});
        return;
      }

      if (response.statusCode != 200) {
        return;
      }

      final body = jsonDecode(response.body);
      final data = body is Map<String, dynamic> ? body['data'] : null;

      await _save(data is Map ? _toBools(data) : const {});
    } catch (e) {
      // Offline: keep what we had
      debugPrint('APP FEATURES ERROR: $e');
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _features = const {};
  }

  static Future<void> _save(Map<String, bool> features) async {
    _features = features;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(features));
  }

  static Map<String, bool> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const {};

    try {
      final data = jsonDecode(raw);
      return data is Map ? _toBools(data) : const {};
    } catch (_) {
      return const {};
    }
  }

  static Map<String, bool> _toBools(Map data) {
    return data.map((key, value) => MapEntry(key.toString(), value == true));
  }
}
