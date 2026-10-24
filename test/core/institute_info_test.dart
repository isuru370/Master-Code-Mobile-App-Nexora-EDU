import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/core/institute/institute_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Institute name / tagline / logo from GET /api/institute, saved on the phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('before the server answers: the build APP_NAME and the app logo', () {
    InstituteInfo.setForTest();

    expect(InstituteInfo.name, InstituteInfo.appName);
    expect(InstituteInfo.shortName, InstituteInfo.appName);
    expect(InstituteInfo.tagline, '');
    expect(InstituteInfo.logo, isA<AssetImage>());
  });

  test('saved details are read at start', () async {
    SharedPreferences.setMockInitialValues({
      'institute_info': jsonEncode({
        'name': 'Mihisara Education Institute',
        'short_name': 'MihisaraEdu',
        'tagline': 'Towards a bright future',
        'logo_url': '',
        'logo_path': null,
      }),
    });
    InstituteInfo.setForTest();

    final before = InstituteInfo.changes.value;
    await InstituteInfo.loadSaved();

    expect(InstituteInfo.name, 'Mihisara Education Institute');
    expect(InstituteInfo.shortName, 'MihisaraEdu');
    expect(InstituteInfo.tagline, 'Towards a bright future');
    expect(InstituteInfo.logo, isA<AssetImage>(), reason: 'no downloaded logo yet');
    expect(InstituteInfo.changes.value, greaterThan(before));
  });

  test('broken saved data keeps the defaults', () async {
    SharedPreferences.setMockInitialValues({'institute_info': 'not json'});
    InstituteInfo.setForTest();

    await InstituteInfo.loadSaved();

    expect(InstituteInfo.name, InstituteInfo.appName);
  });
}
