import 'app_exceptions.dart';

/// Turns any caught error into a message a staff member can read.
///
/// Datasources often wrap errors more than once, e.g.
///   "Exception: Exception: Network error: SocketException: Failed host lookup"
/// The server's own messages ("Student not found.") are kept as they are;
/// technical errors become plain sentences.
String friendlyError(Object error) {
  if (error is AppException && error.message.trim().isNotEmpty) {
    return _clean(error.message);
  }

  return _clean(error.toString());
}

String _clean(String raw) {
  var text = raw.trim();
  final lower = text.toLowerCase();

  // Technical errors -> plain sentences
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection reset') ||
      lower.contains('connection closed')) {
    return 'Cannot reach the server. Check the internet connection and try again.';
  }

  if (lower.contains('timeoutexception') || lower.contains('timed out')) {
    return 'Server is not responding. Check the Wi-Fi / server and try again.';
  }

  if (lower.contains('handshakeexception') || lower.contains('certificate')) {
    return 'Secure connection to the server failed. Check the phone date/time and try again.';
  }

  if (lower.contains('formatexception') ||
      lower.contains('unexpected character') ||
      lower.contains('<!doctype') ||
      lower.contains('<html')) {
    return 'The server sent an unexpected response. Please try again.';
  }

  // Strip "Exception: ", "ClientException: ", "ServerException: " ... (repeated)
  final prefix = RegExp(r'^(?:[A-Za-z_]*(?:Exception|Error)\s*:\s*)+');
  text = text.replaceFirst(prefix, '').trim();

  // "Network error: Server is not responding..." from the datasources
  text = text.replaceFirst(RegExp(r'^Network error:\s*', caseSensitive: false), '').trim();
  text = text.replaceFirst(prefix, '').trim();

  if (text.isEmpty || text == 'null') {
    return 'Something went wrong. Please try again.';
  }

  return text;
}
