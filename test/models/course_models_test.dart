import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/features/admin/courses/data/course_models.dart';

/// test/fixtures/courses_api.json = real responses from the backend's
/// /api/courses endpoints (one student on a special fee, one payment,
/// one attendance).
void main() {
  late Map<String, dynamic> api;

  Map<String, dynamic> data(String key) => api[key]['data'] as Map<String, dynamic>;

  setUpAll(() {
    api = jsonDecode(File('test/fixtures/courses_api.json').readAsStringSync()) as Map<String, dynamic>;
  });

  test('student scan: courses to join', () {
    final result = CourseStudentResult.fromJson(data('student'));

    expect(result.student.customId, 'S1');
    expect(result.enrollments, isEmpty);
    expect(result.availableCourses.single.code, 'CMB-C26001');
    expect(result.availableCourses.single.installmentCount, 6);
    expect(result.availableCourses.single.installmentAmount, 2000);
    expect(result.availableCourses.single.oneTimeFee, 10000);
    expect(result.paymentMethods, contains('cash'));
  });

  test('payment receipt', () {
    final receipt = CourseReceipt.fromJson(data('pay')['receipt'] as Map<String, dynamic>);

    expect(receipt.receiptNumber, 'REC-000001');
    expect(receipt.title, 'COURSE PAYMENT');
    expect(receipt.amount, 1500);
    expect(receipt.balance, 7500);
    expect(receipt.courseFee, 9000);
    expect(receipt.specialFeeReason, 'Sibling');
    expect(receipt.nextDueDate, '2026-12-01');
    expect(receipt.nextDueAmount, 1500);
  });

  test('class days list', () {
    final sessions = (data('sessions')['sessions'] as List)
        .map((s) => CourseSessionItem.fromJson(s as Map<String, dynamic>))
        .toList();

    expect(sessions.single.courseName, 'Diploma in IT');
    expect(sessions.single.canMark, isTrue);
    expect(sessions.single.startTime, '08:00');
  });

  test('attendance marked, with the fee balance', () {
    final result = CourseAttendanceResult.fromJson(data('mark'), api['mark']['message'] as String);

    expect(result.alreadyMarked, isFalse);
    expect(result.student.name, 'A. Silva');
    expect(result.session.status, 'ongoing');
    expect(result.fees.specialFee, isTrue);
    expect(result.fees.balance, 7500);
    expect(result.fees.next?.number, 2);
    expect(result.fees.installments.first.status, 'paid');
    expect(result.attended, 1);
  });

  test('present / absent report with WhatsApp links', () {
    final report = CourseSessionReport.fromJson(data('report'));

    expect(report.present, 1);
    expect(report.absent, 1);
    expect(report.absentList.single.customId, 'S2');
    expect(report.presentList.single.attendedAt, isNotNull);
    expect(report.shareText, contains('*Absent*'));
    expect(report.teachers, isNotEmpty);
    expect(report.teachers.first.whatsappUrl, startsWith('https://wa.me/94'));
  });

  test('bad values do not crash', () {
    final fees = CourseFees.fromJson({'total_fee': '12000.50', 'next_installment': null, 'installments': 'x'});

    expect(fees.totalFee, 12000.5);
    expect(fees.next, isNull);
    expect(fees.installments, isEmpty);
  });
}
