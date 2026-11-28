import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/admin/image_upload/data/datasources/image_upload_remote_datasource.dart';
import '../../features/admin/image_upload/data/models/image_upload/image_upload_request_model.dart';
import '../constants/api_constants.dart';
import '../storage/session_storage.dart';
import 'offline_store.dart';

/// What the offline banner and the dashboard show.
class OfflineStatus {
  const OfflineStatus({
    this.packDate,
    this.classCount = 0,
    this.syncAt,
    this.generatedAt,
    this.pending = 0,
    this.needsReview = 0,
    this.online = true,
    this.syncing = false,
    this.lastSync,
    this.lastMessage,
    this.schedules = const [],
    this.recent = const [],
    this.phoneAttendance = 0,
    this.phonePayments = 0,
    this.phoneTotal = 0,
    this.phoneStudents = 0,
    this.attendanceBySchedule = const {},
  });

  /// When today's data was downloaded.
  final DateTime? generatedAt;

  /// Today's classes (pack), for the dashboard when offline.
  final List<Map<String, dynamic>> schedules;

  /// The newest items saved on this phone (dashboard preview).
  final List<Map<String, dynamic>> recent;

  /// Saved on this phone today (not refused).
  final int phoneAttendance;
  final int phonePayments;
  final double phoneTotal;
  final int phoneStudents;

  /// Attendance marked on this phone per class schedule id.
  final Map<int, int> attendanceBySchedule;

  OfflineStatus copyWith({bool? online, bool? syncing, DateTime? lastSync, String? lastMessage, bool clearMessage = false}) =>
      OfflineStatus(
        packDate: packDate,
        classCount: classCount,
        syncAt: syncAt,
        generatedAt: generatedAt,
        pending: pending,
        needsReview: needsReview,
        online: online ?? this.online,
        syncing: syncing ?? this.syncing,
        lastSync: lastSync ?? this.lastSync,
        lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
        schedules: schedules,
        recent: recent,
        phoneAttendance: phoneAttendance,
        phonePayments: phonePayments,
        phoneTotal: phoneTotal,
        phoneStudents: phoneStudents,
        attendanceBySchedule: attendanceBySchedule,
      );

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
      await _uploadPhotos();
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

    // saved on this phone today and not refused
    final today = _today();
    final todays = queue.where((q) {
      final at = DateTime.tryParse(q['happened_at']?.toString() ?? '')?.toLocal();
      final day = at == null ? '' : '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
      return day == today && q['_status'] != 'failed' && q['_status'] != 'conflict';
    }).toList();
    final payments = todays.where((q) => q['type'] == 'payment').toList();
    final bySchedule = <int, int>{};
    for (final q in todays.where((q) => q['type'] == 'attendance')) {
      final id = int.tryParse(q['schedule_id']?.toString() ?? '') ?? 0;
      bySchedule[id] = (bySchedule[id] ?? 0) + 1;
    }

    final recent = [...queue]
      ..sort((a, b) => (b['happened_at'] ?? '').toString().compareTo((a['happened_at'] ?? '').toString()));
    // waiting / refused first: what still needs the internet or a person
    recent.sort((a, b) => (a['_status'] == 'synced' ? 1 : 0).compareTo(b['_status'] == 'synced' ? 1 : 0));

    final s = status.value;
    status.value = OfflineStatus(
      packDate: pack?['date']?.toString(),
      classCount: (pack?['schedules'] as List?)?.length ?? 0,
      syncAt: DateTime.tryParse(pack?['sync_at']?.toString() ?? '')?.toLocal(),
      generatedAt: DateTime.tryParse(pack?['generated_at']?.toString() ?? '')?.toLocal(),
      pending: queue.where((q) => q['_status'] == 'pending').length,
      needsReview: queue.where((q) => q['_status'] == 'conflict' || q['_status'] == 'failed').length,
      online: s.online,
      syncing: s.syncing,
      lastSync: s.lastSync,
      lastMessage: s.lastMessage,
      schedules: ((pack?['schedules'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      recent: recent.take(4).toList(),
      phoneAttendance: bySchedule.values.fold(0, (a, b) => a + b),
      phonePayments: payments.length,
      phoneTotal: payments.fold(0.0, (sum, q) => sum + (double.tryParse(q['amount']?.toString() ?? '') ?? 0)),
      phoneStudents: todays.where((q) => q['type'] == 'student').length,
      attendanceBySchedule: bySchedule,
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

      final byUuid = {for (final q in chunk) q['local_uuid'].toString(): q};
      final changes = <String, Map<String, dynamic>>{};
      for (final r in results.whereType<Map>()) {
        final status = r['status']?.toString() ?? 'retry';
        if (status == 'retry') continue;   // server error / waits for its student: send again later
        final uuid = r['local_uuid'].toString();
        changes[uuid] = {
          '_status': status == 'duplicate' ? 'synced' : status,
          '_message': r['message'],
          if (r['receipt_number'] != null) '_server_receipt': r['receipt_number'],
          if (r['custom_id'] != null) '_custom_id': r['custom_id'],
          if (r['student_id'] != null) '_server_student_id': r['student_id'],
          // a new student: the phone numbers and other details are on the server now
          if (byUuid[uuid]?['type'] == 'student') 'student': _keepOfStudent(byUuid[uuid]!['student']),
        };
      }
      await OfflineStore.updateQueue(changes);
    }

    return true;
  }

  static Map<String, dynamic> _keepOfStudent(dynamic form) {
    if (form is! Map) return const {};
    return {
      for (final key in const ['initial_name', 'temporary_qr_code', 'card_qr_code'])
        if (form[key] != null) key: form[key],
    };
  }

  /// Photos taken without internet: uploaded once their student is saved.
  Future<void> _uploadPhotos() async {
    final queue = await OfflineStore.readQueue();
    for (final q in queue) {
      final photoId = q['_photo']?.toString();
      final customId = q['_custom_id']?.toString();
      if (photoId == null || customId == null || q['_photo_done'] == true || q['_status'] != 'synced') continue;

      final file = await OfflineStore.photo(photoId);
      if (file == null) {
        await OfflineStore.updateQueue({q['local_uuid'].toString(): {'_photo_done': true}});
        continue;
      }

      await uploadPhoto(photoId, customId);
      await OfflineStore.updateQueue({q['local_uuid'].toString(): {'_photo_done': true}});
    }
  }

  /// Upload a photo kept on the phone to the student (Custom ID). A network
  /// error is thrown (try again later); a refusal by the server is not.
  Future<void> uploadPhoto(String photoId, String customId) async {
    final file = await OfflineStore.photo(photoId);
    if (file == null) return;
    try {
      await ImageUploadRemoteDatasource()
          .updateImage(request: ImageUploadRequestModel(image: file, studentCode: customId))
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      if (e is TimeoutException || e is SocketException || e is http.ClientException) rethrow;
      debugPrint('OFFLINE PHOTO NOT SAVED ($customId): $e');
    }
    await OfflineStore.deletePhoto(photoId);
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
    status.value = status.value.copyWith(
      online: online,
      syncing: syncing,
      lastSync: lastSync,
      lastMessage: message,
      // back online: the last error is over
      clearMessage: online == true && message == null,
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
