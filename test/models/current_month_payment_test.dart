import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/features/admin/qr/data/model/scan_attendance_new/current_month_payment_model.dart';

void main() {
  group('CurrentMonthPaymentModel.fromJson', () {
    test('paid', () {
      final m = CurrentMonthPaymentModel.fromJson({
        'month': '2026-10',
        'month_name': 'October 2026',
        'status': 'paid',
        'is_paid': true,
        'fee': 2000,
        'paid_amount': '2000.00',
        'balance': 0,
      });
      expect(m.isPaid, isTrue);
      expect(m.paidAmount, 2000);
      expect(m.monthName, 'October 2026');
    });

    test('partial is not paid and keeps the balance', () {
      final m = CurrentMonthPaymentModel.fromJson({
        'status': 'partial',
        'is_paid': false,
        'paid_amount': 1000,
        'balance': 1000,
      });
      expect(m.isPaid, isFalse);
      expect(m.isPartial, isTrue);
      expect(m.balance, 1000);
    });

    test('free card counts as paid', () {
      final m = CurrentMonthPaymentModel.fromJson({'status': 'free'});
      expect(m.isFree, isTrue);
      expect(m.isPaid, isTrue);
    });

    test('empty json -> unpaid, zeros', () {
      final m = CurrentMonthPaymentModel.fromJson({});
      expect(m.status, 'unpaid');
      expect(m.isPaid, isFalse);
      expect(m.fee, 0);
    });
  });
}
