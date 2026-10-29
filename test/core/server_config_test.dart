import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexorait_education_app/core/constants/api_constants.dart';
import 'package:nexorait_education_app/core/institute/server_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789AbCd'; // 40 chars
  const qrText = 'https://savidyaedu.nexorait.lk/app-setup?key=$key';

  group('parseQr (release rules)', () {
    InstituteQr parse(String text) => ServerConfig.parseQr(text, allowLocal: false);

    test('reads the server address and key of a Nexora QR', () {
      final qr = parse(qrText);
      expect(qr.baseUrl, 'https://savidyaedu.nexorait.lk');
      expect(qr.key, key);
    });

    test('host is checked without case', () {
      expect(parse('https://SavidyaEdu.NexoraIT.lk/app-setup?key=$key').baseUrl,
          'https://savidyaedu.nexorait.lk');
    });

    final rejected = {
      'plain text': 'S00123',
      'student card QR': 'NX-ST-000123',
      'http (not https)': 'http://savidyaedu.nexorait.lk/app-setup?key=$key',
      'other domain': 'https://evil.com/app-setup?key=$key',
      'look-alike domain': 'https://savidyaedu.nexorait.lk.evil.com/app-setup?key=$key',
      'domain ending the same': 'https://fakenexorait.lk/app-setup?key=$key',
      'extra port': 'https://savidyaedu.nexorait.lk:8443/app-setup?key=$key',
      'user info': 'https://x@savidyaedu.nexorait.lk/app-setup?key=$key',
      'wrong path': 'https://savidyaedu.nexorait.lk/login?key=$key',
      'short key': 'https://savidyaedu.nexorait.lk/app-setup?key=abc',
      'no key': 'https://savidyaedu.nexorait.lk/app-setup',
    };

    rejected.forEach((name, text) {
      test('rejects $name', () {
        expect(() => parse(text), throwsA(isA<InstituteSetupException>()));
      });
    });
  });

  test('debug builds may use a local test server', () {
    final qr = ServerConfig.parseQr('http://192.168.1.10:8000/app-setup?key=$key', allowLocal: true);
    expect(qr.baseUrl, 'http://192.168.1.10:8000');
  });

  group('verify', () {
    final qr = ServerConfig.parseQr(qrText, allowLocal: false);

    test('returns the institute when the server accepts the key', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {'name': 'Savidya Education', 'api_base_url': 'https://savidyaedu.nexorait.lk'},
          }),
          200,
        );
      });

      final data = await ServerConfig.verify(qr, client: client);

      expect(data['name'], 'Savidya Education');
      expect(sent.url.toString(), 'https://savidyaedu.nexorait.lk/api/app-setup/verify');
      expect(jsonDecode(sent.body), {'key': key});
    });

    Future<Object?> failure(http.Response response) async {
      try {
        await ServerConfig.verify(qr, client: MockClient((_) async => response));
        return null;
      } catch (e) {
        return e;
      }
    }

    test('invalid key shows the server message', () async {
      final e = await failure(http.Response(jsonEncode({'message': 'Invalid QR code.'}), 422));
      expect(e, isA<InstituteSetupException>());
      expect((e as InstituteSetupException).message, 'Invalid QR code.');
    });

    test('too many tries', () async {
      final e = await failure(http.Response('', 429));
      expect((e as InstituteSetupException).message, contains('Too many tries'));
    });

    test('a server answering for another address is refused', () async {
      final e = await failure(http.Response(
        jsonEncode({
          'data': {'name': 'X', 'api_base_url': 'https://other.nexorait.lk'},
        }),
        200,
      ));
      expect((e as InstituteSetupException).message, contains('does not match'));
    });

    test('a non-JSON answer is refused', () async {
      final e = await failure(http.Response('<html>', 200));
      expect(e, isA<InstituteSetupException>());
    });
  });

  test('saved address is used by the API URLs and can be cleared', () async {
    SharedPreferences.setMockInitialValues({});

    await ServerConfig.save('https://savidyaedu.nexorait.lk/');
    expect(ServerConfig.isConfigured, isTrue);
    expect(ApiConstants.apiUrl, 'https://savidyaedu.nexorait.lk/api');
    expect(ApiConstants.login, 'https://savidyaedu.nexorait.lk/api/login');

    ServerConfig.setSavedForTest(null);
    await ServerConfig.load();
    expect(ServerConfig.baseUrl, 'https://savidyaedu.nexorait.lk');

    await ServerConfig.clear();
    expect(ServerConfig.isConfigured, isFalse);
    expect(ServerConfig.baseUrl, '');
  });
}
