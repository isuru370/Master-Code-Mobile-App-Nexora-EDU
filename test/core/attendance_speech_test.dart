import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/core/voice/attendance_speech.dart';

void main() {
  group('English part: name, subject, grade', () {
    test('normal class', () {
      expect(
        AttendanceSpeech.english(name: 'K. Perera', subject: 'ENGLISH', grade: '10'),
        'K. Perera. English, Grade 10.',
      );
    });

    test('A/L grade, long subject in short, upper-case name', () {
      expect(
        AttendanceSpeech.english(
          name: 'K.A. NIMALI  SILVA',
          subject: 'INFORMATION AND COMMUNICATION TECHNOLOGY',
          grade: '2027 A/L',
        ),
        'K.A. Nimali Silva. ICT, 2027 A L.',
      );
    });

    test('already marked is said first', () {
      expect(
        AttendanceSpeech.english(name: 'Kasun', subject: 'Maths', grade: '8', alreadyMarked: true),
        'Already marked. Kasun. Maths, Grade 8.',
      );
    });

    test('grades', () {
      expect(AttendanceSpeech.gradeText('ALL'), 'All grades');
      expect(AttendanceSpeech.gradeText('2026 o/l'), '2026 O L');
      expect(AttendanceSpeech.gradeText('From preschool to 5'), 'From preschool to 5');
      expect(AttendanceSpeech.gradeText(''), '');
    });

    test('missing parts are left out', () {
      expect(AttendanceSpeech.english(name: 'Kasun.', subject: '', grade: ''), 'Kasun.');
    });
  });

  group('Sinhala part: this month', () {
    test('paid / not paid in Sinhala', () {
      expect(AttendanceSpeech.payment('paid', sinhala: true), 'මේ මාසේ ගාස්තු ගෙවා ඇත.');
      expect(AttendanceSpeech.payment('unpaid', sinhala: true), 'මේ මාසේ ගාස්තු ගෙවා නැත.');
      // part paid = not fully paid
      expect(AttendanceSpeech.payment('partial', sinhala: true), 'මේ මාසේ ගාස්තු ගෙවා නැත.');
    });

    test('English when the phone has no Sinhala voice', () {
      expect(AttendanceSpeech.payment('paid', sinhala: false), 'Paid.');
      expect(AttendanceSpeech.payment('unpaid', sinhala: false), 'Not paid.');
    });

    test('free card: no words (a beep)', () {
      expect(AttendanceSpeech.payment('free', sinhala: true), isNull);
      expect(AttendanceSpeech.isFree('free'), isTrue);
      expect(AttendanceSpeech.isFree('paid'), isFalse);
      expect(AttendanceSpeech.payment(null, sinhala: true), isNull);
    });
  });
}
