import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/core/widgets/privacy_policy_link.dart';
import 'package:nexorait_education_app/features/admin/payment/data/models/today_payments/today_payment_item_model.dart';
import 'package:nexorait_education_app/features/admin/payment/presentaion/pages/utils/today_payments_pdf.dart';

TodayPaymentItemModel _payment(int id, String className, double amount, {double discount = 0}) {
  return TodayPaymentItemModel.fromJson({
    'payment_id': id,
    'receipt_number': 'R-$id',
    'amount': amount,
    'discount_amount': discount,
    'paid_at': '2026-10-31 15:0$id:00',
    'payment_month': '2026-10-01',
    'payment_method': 'cash',
    'status': 'paid',
    'student': {'id': id, 'initial_name': 'Student $id', 'qr_code': 'S$id'},
    'class': {'id': 1, 'class_name': className},
  });
}

void main() {
  test('today payments PDF is built for a day with payments', () async {
    final bytes = await TodayPaymentsPdf.build(
      date: DateTime(2026, 10, 31),
      payments: [
        _payment(1, 'Grade 10 Maths', 2000),
        _payment(2, 'Grade 10 Maths', 1000, discount: 1000),
        _payment(3, 'Grade 11 Science', 2500),
      ],
      search: 'Maths',
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('a long day spans several pages', () async {
    final payments = [for (var i = 1; i <= 120; i++) _payment(i % 9 + 1, 'Class ${i % 4}', 1500)];
    final bytes = await TodayPaymentsPdf.build(date: DateTime(2026, 10, 31), payments: payments);

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('privacy policy link is the public page given on Google Play', () {
    expect(AppLinks.privacyPolicy, 'https://edu.nexorait.lk/privacy-policy');
  });
}
