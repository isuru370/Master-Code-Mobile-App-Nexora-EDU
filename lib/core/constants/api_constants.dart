import '../institute/server_config.dart';

class ApiConstants {
  /// Server address of this phone's institute.
  ///
  /// One app for every institute: the address comes from the institute QR
  /// scanned on first start (see ServerConfig). A build made for a single
  /// institute still works and skips the QR:
  ///
  ///   flutter build apk --release --dart-define=API_BASE_URL=https://mihisaraeducation.nexorait.lk
  ///
  /// These are getters (not const) because the address is known only at run time.
  static String get baseUrl => ServerConfig.baseUrl;
  static String get apiUrl => '$baseUrl/api';

  static String get login => '$apiUrl/login';
  static String get logout => '$apiUrl/logout';
  static String get me => '$apiUrl/me';
  static String get profile => '$apiUrl/profile';

  static const String contentType = 'Content-Type';
  static const String accept = 'Accept';
  static const String authorization = 'Authorization';

  static const String applicationJson = 'application/json; charset=UTF-8';

  static Map<String, String> headers({String? token}) {
    final headers = <String, String>{
      contentType: applicationJson,
      accept: 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers[authorization] = 'Bearer $token';
    }

    return headers;
  }
}
