import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Files of the staff app's offline mode, in the app's own folder:
///
///  - the day's pack (GET /api/offline/pack): today's classes and students
///  - the queue: attendance and payments recorded offline, sent to
///    POST /api/offline/sync. An item stays until the server answered.
///
/// No phone numbers or other personal details are kept here.
class OfflineStore {
  OfflineStore._();

  static const _deviceKey = 'offline_device_id';
  static const _receiptKey = 'offline_receipt_counter';

  /// One writer at a time (a scan and a sync can run together).
  static Future<void> _lock = Future.value();

  static Future<T> _locked<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  static Future<File> _file(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/nexora_offline_$name.json');
  }

  static Future<dynamic> _read(String name) async {
    try {
      final file = await _file(name);
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String name, Object value) async {
    final file = await _file(name);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(file.path);
  }

  /* ------------------------------------------------------------ pack */

  static Future<Map<String, dynamic>?> readPack() async {
    final pack = await _read('pack');
    return pack is Map<String, dynamic> ? pack : null;
  }

  static Future<void> writePack(Map<String, dynamic> pack) => _locked(() => _write('pack', pack));

  static Future<void> clearPack() => _locked(() async {
        final file = await _file('pack');
        if (await file.exists()) await file.delete();
      });

  /* ----------------------------------------------------------- queue */

  static Future<List<Map<String, dynamic>>> readQueue() async {
    final queue = await _read('queue');
    if (queue is! List) return [];
    return queue.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addToQueue(Map<String, dynamic> item) => _locked(() async {
        final queue = await readQueue();
        queue.add(item);
        await _write('queue', queue);
      });

  /// Change items by local_uuid (sync results).
  static Future<void> updateQueue(Map<String, Map<String, dynamic>> changes) => _locked(() async {
        final queue = await readQueue();
        for (final item in queue) {
          final change = changes[item['local_uuid']];
          if (change != null) item.addAll(change);
        }
        // keep finished items for 3 days (Offline sync list on the phone)
        final cutoff = DateTime.now().subtract(const Duration(days: 3));
        queue.removeWhere((item) {
          if (item['_status'] == 'pending') return false;
          final at = DateTime.tryParse(item['happened_at']?.toString() ?? '');
          return at != null && at.isBefore(cutoff);
        });
        await _write('queue', queue);
      });

  /* ------------------------------------------------------ device / ids */

  /// Short id of this phone, also on its offline receipts (OF-A3F2-0007).
  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceKey);
    if (id == null || id.isEmpty) {
      final random = Random.secure();
      id = List.generate(4, (_) => random.nextInt(16).toRadixString(16)).join().toUpperCase();
      await prefs.setString(_deviceKey, id);
    }
    return id;
  }

  static Future<String> nextReceiptNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_receiptKey) ?? 0) + 1;
    await prefs.setInt(_receiptKey, next);
    final device = await deviceId();
    return 'OF-$device-${next.toString().padLeft(4, '0')}';
  }

  /// Random UUID v4.
  static String uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Local time with its offset, e.g. 2026-12-01T15:05:00.000+05:30.
  static String timestamp(DateTime time) {
    final offset = time.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${time.toIso8601String()}$sign$hours:$minutes';
  }
}
