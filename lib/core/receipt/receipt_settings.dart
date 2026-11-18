import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../storage/session_storage.dart';

/// What the class payment receipt prints (web: Settings > Receipt).
/// Everything is on unless the institute turned it off. Loaded from
/// GET /api/receipt-settings and kept for 10 minutes; when the server
/// cannot be reached the last settings (or all on) are used, so printing
/// never waits or fails because of this.
class ReceiptSettings {
  final Map<String, bool> _fields;
  final String footer;

  const ReceiptSettings._(this._fields, this.footer);

  static const ReceiptSettings allOn = ReceiptSettings._({}, '');

  static ReceiptSettings? _cached;
  static DateTime? _loadedAt;
  static String? _loadedFor; // login token: another login loads again

  /// Missing field = shown (an older server sends nothing).
  bool shows(String field) => _fields[field] ?? true;

  bool get date => shows('date');
  bool get month => shows('month');
  bool get studentName => shows('student_name');
  bool get studentId => shows('student_id');
  bool get grade => shows('grade');
  bool get teacher => shows('teacher');
  bool get category => shows('category');
  bool get feeOption => shows('fee_option');
  bool get receiptNumber => shows('receipt_number');
  bool get fees => shows('fees');
  bool get classesCount => shows('classes_count');
  bool get keepNote => shows('keep_note');

  static Future<ReceiptSettings> load() async {
    final token = await SessionStorage.getToken();

    if (_loadedFor != token) clear();

    final cached = _cached;
    final loadedAt = _loadedAt;

    if (cached != null && loadedAt != null && DateTime.now().difference(loadedAt).inMinutes < 10) {
      return cached;
    }

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConstants.apiUrl}/receipt-settings'),
            headers: ApiConstants.headers(token: token),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body is Map && body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : <String, dynamic>{};

        final fields = <String, bool>{};
        data.forEach((key, value) {
          if (value is bool) fields[key] = value;
        });

        _cached = ReceiptSettings._(fields, (data['footer'] ?? '').toString().trim());
        _loadedAt = DateTime.now();
        _loadedFor = token;
        return _cached!;
      }
    } catch (_) {
      // Offline / old server: fall back below
    }

    return cached ?? allOn;
  }

  static void clear() {
    _cached = null;
    _loadedAt = null;
    _loadedFor = null;
  }
}
