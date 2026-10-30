import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/features/admin/payment/data/models/mark_payment_item_model.dart';
import 'package:nexorait_education_app/features/admin/payment/data/payment_month_info.dart';

void main() {
  test('reads the month info with the attendance rule and tute', () {
    final info = PaymentMonthInfo.fromJson({
      'enrollment_id': 12,
      'payment_month_name': 'November 2026',
      'attendance_count': 1,
      'gross_fee': 2000,
      'rule': {'enabled': true, 'percent': 50, 'reason': 'Attendance 1: 50% fee', 'no_fee': false},
      'suggested_amount': 1000,
      'custom_amount': false,
      'already_paid': false,
      'paid': null,
      'tute': {'enabled': true, 'issued': true, 'issued_at': '2026-11-03'},
    });

    expect(info.enrollmentId, 12);
    expect(info.attendanceCount, 1);
    expect(info.ruleEnabled, isTrue);
    expect(info.rulePercent, 50);
    expect(info.suggestedAmount, 1000);
    expect(info.amountEditable, isTrue);
    expect(info.tuteEnabled, isTrue);
    expect(info.tuteIssued, isTrue);
    expect(info.tuteIssuedAt, '2026-11-03');
  });

  test('rules off: only the attendance, amount not editable', () {
    final info = PaymentMonthInfo.fromJson({
      'enrollment_id': '5',
      'attendance_count': '3',
      'gross_fee': '1500.00',
      'rule': {'enabled': false, 'percent': 100, 'reason': null, 'no_fee': false},
      'suggested_amount': '1500.00',
      'custom_amount': false,
      'already_paid': true,
      'paid': {'receipt_number': 'REC-000011'},
      'tute': {'enabled': false, 'issued': false, 'issued_at': null},
    });

    expect(info.enrollmentId, 5);
    expect(info.attendanceCount, 3);
    expect(info.amountEditable, isFalse);
    expect(info.alreadyPaid, isTrue);
    expect(info.paidReceipt, 'REC-000011');
    expect(info.tuteEnabled, isFalse);
  });

  test('give_tute is only sent when ticked', () {
    const base = MarkPaymentItemModel(code: 'S1', enrollmentId: 1, amount: 1000, paymentMonth: '2026-11');
    const withTute = MarkPaymentItemModel(
      code: 'S1', enrollmentId: 1, amount: 1000, paymentMonth: '2026-11', giveTute: true,
    );

    expect(base.toJson().containsKey('give_tute'), isFalse);
    expect(withTute.toJson()['give_tute'], isTrue);
  });
}
