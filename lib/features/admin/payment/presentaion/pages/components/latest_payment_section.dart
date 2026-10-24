import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../qr/data/model/read_payment/read_last_payment_model.dart';
import '../../../../../../core/theme/app_colors.dart';

class LatestPaymentSection extends StatelessWidget {
  final ReadLastPaymentModel latestPayment;

  const LatestPaymentSection({super.key, required this.latestPayment});

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.tryParse(latestPayment.paidAt);

    /// current year-month
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    /// latest payment month
    final paymentMonth = latestPayment.paymentMonth;

    /// check paid status
    final bool isPaid = paymentMonth == currentMonth;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPaid
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaid ? AppColors.successLight : AppColors.dangerLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Latest Payment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isPaid ? AppColors.successLight : AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isPaid ? 'PAID' : 'UNPAID',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isPaid ? AppColors.successText : AppColors.dangerText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Amount: LKR ${latestPayment.amount}'),
          Text('Discount: LKR ${latestPayment.discountAmount}'),
          Text('Payment Month: ${latestPayment.paymentMonth}'),

          Text(
            'Date: ${parsedDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(parsedDate.toLocal()) : latestPayment.paidAt}',
          ),
        ],
      ),
    );
  }
}
