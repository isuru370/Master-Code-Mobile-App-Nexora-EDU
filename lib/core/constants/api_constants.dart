class ApiConstants {
  /// Server address. Set it at build time, no code change needed:
  ///
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
  ///   flutter build apk --release --dart-define=API_BASE_URL=https://mihisaraeducation.nexorait.lk
  ///
  /// Without --dart-define the default below is used.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.17.162.230:8000',
  );
  static const String apiUrl = '$baseUrl/api';

  static const String login = '$apiUrl/login';
  static const String logout = '$apiUrl/logout';
  static const String me = '$apiUrl/me';
  static const String profile = '$apiUrl/profile';

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
