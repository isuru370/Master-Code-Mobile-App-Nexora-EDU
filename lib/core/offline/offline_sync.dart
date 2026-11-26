import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../storage/session_storage.dart';
import 'offline_store.dart';

/// What the offline banner shows.
class OfflineStatus {
  const OfflineStatus({
    this.packDate,
    this.classCount = 0,
    this.syncAt,
    this.pending = 0,
    this.needsReview = 0,
    this.online = true,
    this.syncing = false,
    this.lastSync,
    this.lastMessage,
  });

  /// Date of the pack on the phone (today = ready for offline).
  final String? packDate;
  final int classCount;

  /// End of the last class today: the phone syncs by then at the latest.
  final DateTime? syncAt;

  /// Recorded offline, not on the server yet.
  final int pending;

  /// Refused by the server (conflict / failed): a person must check them.
  final int needsReview;

  final bool online;
  final bool syncing;
  final DateTime? lastSync;
  final String? lastMessage;

  bool get readyToday {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return packDate == today;
  }
}

/// Keeps the day's pack fresh and sends the offline queue:
///  - every minute while the app is open, and right after something was
///    recorded offline - so it goes as soon as there is internet
///  - the pack is downloaded once a day (and again with "Sync now")
class OfflineSync {
  OfflineSync._();

  static final OfflineSync instance = OfflineSync._();

  final ValueNotifier<OfflineStatus> status = ValueNotifier(const OfflineStatus());

  Timer? _timer;
  bool _busy = false;

  /// Start once the staff user is signed in (dashboard).
  void start() {
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => run());
    run();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Something was saved offline: show it, and try to send it now.
  void queued() {
    refreshCounts();
    Future.delayed(const Duration(seconds: 2), () => run());
  }

  /// Sync now: send the queue, then download today's pack.
  Future<void> run({bool forcePack = false}) async {
    if (_busy) return;
    _busy = true;
    _set(syncing: true);

    try {
      final sent = await _sendQueue();
      final pack = await OfflineStore.readPack();
      final today = _today();
      if (forcePack || pack == null || pack['date'] != today || sent) {
        await _downloadPack();
      }
      _set(online: true, lastSync: DateTime.now(), message: null);
    } catch (e) {
      final offline = e is! _ServerAnswer;
      _set(online: !offline, message: offline ? 'No internet' : e.toString());
    } finally {
      _busy = false;
      await refreshCounts();
      _set(syncing: false);
    }
  }

  Future<void> refreshCounts() async {
    final queue = await OfflineStore.readQueue();
    final pack = await OfflineStore.readPack();
    status.value = OfflineStatus(
      packDate: pack?['date']?.toString(),
      classCount: (pack?['schedules'] as List?)?.length ?? 0,
      syncAt: DateTime.tryParse(pack?['sync_at']?.toString() ?? '')?.toLocal(),
      pending: queue.where((q) => q['_status'] == 'pending').length,
      needsReview: queue.where((q) => q['_status'] == 'conflict' || q['_status'] == 'failed').length,
      online: status.value.online,
      syncing: status.value.syncing,
      lastSync: status.value.lastSync,
      lastMessage: status.value.lastMessage,
    );
  }

  /// Items on this phone (newest first) for the "Offline items" list.
  Future<List<Map<String, dynamic>>> items() async {
    final queue = await OfflineStore.readQueue();
    queue.sort((a, b) => (b['happened_at'] ?? '').toString().compareTo((a['happened_at'] ?? '').toString()));
    return queue;
  }

  /// True when the queue is empty (safe to log out).
  Future<bool> allSent() async {
    await run();
    final queue = await OfflineStore.readQueue();
    return !queue.any((q) => q['_status'] == 'pending');
  }

  /* --------------------------------------------------------------- */

  Future<bool> _sendQueue() async {
    final queue = await OfflineStore.readQueue();
    final pending = queue.where((q) => q['_status'] == 'pending').toList();
    if (pending.isEmpty) return false;

    final token = await SessionStorage.getToken();
    if (token == null || token.isEmpty) return false;

    final device = await OfflineStore.deviceId();

    for (var i = 0; i < pending.length; i += 100) {
      final chunk = pending.sublist(i, i + 100 > pending.length ? pending.length : i + 100);
      final body = jsonEncode({
        'device_id': 'phone-$device',
        'items': chunk.map((q) => Map.fromEntries(q.entries.where((e) => !e.key.startsWith('_')))).toList(),
      });

      final response = await http
          .post(
            Uri.parse('${ApiConstants.apiUrl}/offline/sync'),
            headers: ApiConstants.headers(token: token),
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw _ServerAnswer('Sync refused by the server (${response.statusCode}).');
      }

      final decoded = jsonDecode(response.body);
      final results = decoded is Map ? decoded['results'] : null;
      if (results is! List) throw _ServerAnswer('Invalid sync answer.');

      final changes = <String, Map<String, dynamic>>{};
      for (final r in results.whereType<Map>()) {
        final status = r['status']?.toString() ?? 'retry';
        if (status == 'retry') continue;   // server error: send again later
        changes[r['local_uuid'].toString()] = {
          '_status': status == 'duplicate' ? 'synced' : status,
          '_message': r['message'],
          if (r['receipt_number'] != null) '_server_receipt': r['receipt_number'],
        };
      }
      await OfflineStore.updateQueue(changes);
    }

    return true;
  }

  Future<void> _downloadPack() async {
    final token = await SessionStorage.getToken();
    if (token == null || token.isEmpty) return;

    final response = await http
        .get(Uri.parse('${ApiConstants.apiUrl}/offline/pack'), headers: ApiConstants.headers(token: token))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 404) return;   // server without offline mode
    if (response.statusCode != 200) throw _ServerAnswer('Could not download today\'s offline data (${response.statusCode}).');

    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is Map<String, dynamic>) await OfflineStore.writePack(data);
  }

  void _set({bool? online, bool? syncing, DateTime? lastSync, String? message}) {
    final s = status.value;
    status.value = OfflineStatus(
      packDate: s.packDate,
      classCount: s.classCount,
      syncAt: s.syncAt,
      pending: s.pending,
      needsReview: s.needsReview,
      online: online ?? s.online,
      syncing: syncing ?? s.syncing,
      lastSync: lastSync ?? s.lastSync,
      lastMessage: message ?? (online == true ? null : s.lastMessage),
    );
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class _ServerAnswer implements Exception {
  _ServerAnswer(this.message);
  final String message;
  @override
  String toString() => message;
}
