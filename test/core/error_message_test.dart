import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/core/errors/app_exceptions.dart';
import 'package:nexorait_education_app/core/errors/error_message.dart';

void main() {
  group('friendlyError', () {
    test('keeps the server message and drops "Exception:" prefixes', () {
      expect(friendlyError(Exception('Student not found.')), 'Student not found.');
      expect(friendlyError(Exception('Exception: Exception: QR code invalid')), 'QR code invalid');
      expect(friendlyError(const ServerException('You do not have access to this branch.', 403)),
          'You do not have access to this branch.');
    });

    test('network problems become a plain sentence', () {
      expect(friendlyError(Exception('Network error: SocketException: Failed host lookup: x.lk')),
          'Cannot reach the server. Check the internet connection and try again.');
      expect(friendlyError(Exception('TimeoutException after 0:00:30.000000')),
          'Server is not responding. Check the Wi-Fi / server and try again.');
    });

    test('an HTML error page is not shown to the user', () {
      expect(friendlyError(const FormatException('Unexpected character', '<!DOCTYPE html>')),
          'The server sent an unexpected response. Please try again.');
    });

    test('datasource "Network error:" wrapper is removed', () {
      expect(friendlyError(Exception('Network error: Server is not responding. Check the Wi-Fi / server and try again.')),
          'Server is not responding. Check the Wi-Fi / server and try again.');
    });

    test('empty message gets a default', () {
      expect(friendlyError(Exception('')), 'Something went wrong. Please try again.');
    });
  });
}
