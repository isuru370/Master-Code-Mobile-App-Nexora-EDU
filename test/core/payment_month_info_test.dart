import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/features/admin/payment/data/models/mark_payment_item_model.dart';
import 'package:nexorait_education_app/features/admin/payment/data/payment_month_info.dart';

void main() {
  test('reads fee options, attendance and tute', () {
    final info = PaymentMonthInfo.fromJson({
      'enrollment_id': 12,
      'payment_month_name': 'November 2026',
      'attendance_count': 1,
      'no_attendance': false,
      'gross_fee': 2000,
      'fee_option_enabled': true,
      'fee_options': [
        {'id': 3, 'label': 'Normal', 'fee': 2000, 'amount': 2000, 'is_student_option': true},
        {'id': 7, 'label': 'Half', 'fee': 1000, 'amount': 1000, 'is_student_option': false},
      ],
      'custom_amount': false,
      'already_paid': false,
      'paid': null,
      'tute': {'enabled': true, 'issued': true, 'issued_at': '2026-11-03'},
    });

    expect(info.enrollmentId, 12);
    expect(info.attendanceCount, 1);
    expect(info.feeOptionEnabled, isTrue);
    expect(info.feeOptions, hasLength(2));
    expect(info.feeOptions[1].label, 'Half');
    expect(info.feeOptions[1].amount, 1000);
    expect(info.studentOption?.id, 3);
    expect(info.tuteIssued, isTrue);
  });

  test('rules off: attendance only, no options', () {
    final info = PaymentMonthInfo.fromJson({
      'enrollment_id': '5',
      'attendance_count': '0',
      'no_attendance': true,
      'gross_fee': '1500.00',
      'fee_option_enabled': false,
      'fee_options': [],
      'custom_amount': false,
      'already_paid': true,
      'paid': {'receipt_number': 'REC-000011'},
      'tute': {'enabled': false, 'issued': false, 'issued_at': null},
    });

    expect(info.attendanceCount, 0);
    expect(info.noAttendance, isTrue);
    expect(info.feeOptions, isEmpty);
    expect(info.studentOption, isNull);
    expect(info.paidReceipt, 'REC-000011');
  });

  test('give_tute and fee_option_id are only sent when set', () {
    const base = MarkPaymentItemModel(code: 'S1', enrollmentId: 1, amount: 1000, paymentMonth: '2026-11');
    const withExtras = MarkPaymentItemModel(
      code: 'S1', enrollmentId: 1, amount: 1000, paymentMonth: '2026-11', giveTute: true, feeOptionId: 7,
    );

    expect(base.toJson().containsKey('give_tute'), isFalse);
    expect(base.toJson().containsKey('fee_option_id'), isFalse);
    expect(withExtras.toJson()['give_tute'], isTrue);
    expect(withExtras.toJson()['fee_option_id'], 7);
  });
}
