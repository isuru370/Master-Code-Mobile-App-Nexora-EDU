/// `data.current_month_payment` from POST /api/new-attendance/scan.
///
/// status: free | paid | partial | unpaid
class CurrentMonthPaymentModel {
  /// "2026-10"
  final String month;

  /// "October 2026"
  final String monthName;
  final String status;
  final bool isPaid;
  final double fee;
  final double paidAmount;
  final double balance;

  const CurrentMonthPaymentModel({
    required this.month,
    required this.monthName,
    required this.status,
    required this.isPaid,
    required this.fee,
    required this.paidAmount,
    required this.balance,
  });

  bool get isFree => status == 'free';

  bool get isPartial => status == 'partial';

  factory CurrentMonthPaymentModel.fromJson(Map<String, dynamic> json) {
    final status = (json['status'] ?? 'unpaid').toString().toLowerCase();

    return CurrentMonthPaymentModel(
      month: json['month']?.toString() ?? '',
      monthName: json['month_name']?.toString() ?? '',
      status: status,
      isPaid: json['is_paid'] == true || status == 'paid' || status == 'free',
      fee: _toDouble(json['fee']),
      paidAmount: _toDouble(json['paid_amount']),
      balance: _toDouble(json['balance']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
