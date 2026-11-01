import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/core/utils/app_datetime.dart';

void main() {
  test('UTC time from the API is shown as Sri Lanka time', () {
    final date = AppDateTime.parseApi('2026-11-01T06:35:00.000000Z')!;
    expect([date.year, date.month, date.day, date.hour, date.minute], [2026, 11, 1, 12, 5]);
    expect(date.isUtc, isFalse);
  });

  test('crosses midnight correctly', () {
    final date = AppDateTime.parseApi('2026-10-31T20:00:00Z')!;
    expect([date.month, date.day, date.hour, date.minute], [11, 1, 1, 30]);
  });

  test('local time without a zone is kept', () {
    final date = AppDateTime.parseApi('2026-11-01 12:05:00')!;
    expect([date.hour, date.minute], [12, 5]);
  });

  test('empty or bad values', () {
    expect(AppDateTime.parseApi(''), isNull);
    expect(AppDateTime.parseApi(null), isNull);
    expect(AppDateTime.parseApi('abc'), isNull);
  });
}
