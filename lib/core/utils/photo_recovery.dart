import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Brings back a photo when the phone killed the app while the gallery
/// (or the crop screen) was open.
///
/// Before the gallery opens the page calls [markPending]; when the result
/// comes back it calls [clear]. If the app was killed in between, the
/// dashboard calls [resumeIfNeeded] after start-up: it opens the photo page
/// again with the picked photo (image_picker keeps it for us).
class PhotoRecovery {
  PhotoRecovery._();

  static const String _key = 'pending_photo_page';

  /// Photo page arguments: the recovered photo path (if any)
  static const String recoveredPathArg = 'recovered_image_path';

  /// Photo page arguments: true when the app was restarted
  static const String recoveredArg = 'recovered';

  static Future<void> markPending(String route, Map<String, dynamic> arguments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode({'route': route, 'arguments': arguments}));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  static Future<void> resumeIfNeeded(BuildContext context) async {
    Map<String, dynamic>? pending;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;

      await prefs.remove(_key);
      pending = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    String? path;

    if (Platform.isAndroid) {
      try {
        final lost = await ImagePicker().retrieveLostData();
        if (!lost.isEmpty && lost.file != null) {
          path = lost.file!.path;
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    final route = pending['route'] as String?;
    if (route == null) return;

    final arguments = Map<String, dynamic>.from(
      (pending['arguments'] as Map?) ?? const {},
    );
    arguments[recoveredArg] = true;
    arguments[recoveredPathArg] = path;

    Navigator.of(context).pushNamed(route, arguments: arguments);
  }
}
