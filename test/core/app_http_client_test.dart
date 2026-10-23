import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexorait_education_app/core/network/app_http_client.dart';

void main() {
  test('an HTML error page becomes a JSON message', () async {
    final client = AppHttpClient(
      inner: MockClient((_) async => http.Response(
            '<!DOCTYPE html><html><body>502 Bad Gateway</body></html>',
            502,
            headers: {'content-type': 'text/html'},
          )),
    );

    final response = await client.get(Uri.parse('https://x.lk/api/students'));
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    expect(response.statusCode, 502);
    expect(json['success'], false);
    expect(json['message'], 'The server is not available right now (502). Please try again in a few minutes.');
  });

  test('JSON errors from Laravel are passed through unchanged', () async {
    final client = AppHttpClient(
      inner: MockClient((_) async => http.Response(
            jsonEncode({'success': false, 'message': 'QR code invalid'}),
            404,
            headers: {'content-type': 'application/json'},
          )),
    );

    final response = await client.get(Uri.parse('https://x.lk/api/students/filter'));

    expect(jsonDecode(response.body)['message'], 'QR code invalid');
  });

  test('Accept: application/json is added', () async {
    String? accept;
    final client = AppHttpClient(
      inner: MockClient((request) async {
        accept = request.headers['Accept'];
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }),
    );

    await client.get(Uri.parse('https://x.lk/api/me'));

    expect(accept, 'application/json');
  });
}
