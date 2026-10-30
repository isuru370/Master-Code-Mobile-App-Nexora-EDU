class MarkPaymentItemModel {
  final String code;
  final int enrollmentId;
  final double amount;
  final double? discountAmount;
  final String paymentMonth;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? markMethod;
  final String? note;

  /// Payment Rules > tute: also give this month's tute (optional).
  final bool giveTute;

  /// Payment Rules > fee option: option picked for this month only.
  final int? feeOptionId;

  const MarkPaymentItemModel({
    required this.code,
    required this.enrollmentId,
    required this.amount,
    this.discountAmount,
    required this.paymentMonth,
    this.paidAt,
    this.paymentMethod,
    this.markMethod,
    this.note,
    this.giveTute = false,
    this.feeOptionId,
  });

  factory MarkPaymentItemModel.fromJson(Map<String, dynamic> json) {
    return MarkPaymentItemModel(
      code: json['code']?.toString() ?? '',

      enrollmentId: json['enrollment_id'] is int
          ? json['enrollment_id'] as int
          : int.tryParse(json['enrollment_id']?.toString() ?? '') ?? 0,

      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,

      discountAmount: json['discount_amount'] == null
          ? null
          : double.tryParse(json['discount_amount'].toString()),

      paymentMonth: json['payment_month']?.toString() ?? '',

      paidAt: json['paid_at'] == null
          ? null
          : DateTime.tryParse(json['paid_at'].toString()),

      paymentMethod: json['payment_method']?.toString(),

      markMethod: json['mark_method']?.toString(),

      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'enrollment_id': enrollmentId,
      'amount': amount,
      'discount_amount': discountAmount,
      'payment_month': paymentMonth,
      'paid_at': paidAt?.toIso8601String(),
      'payment_method': paymentMethod,
      'mark_method': markMethod,
      'note': note,
      if (giveTute) 'give_tute': true,
      if (feeOptionId != null) 'fee_option_id': feeOptionId,
    };
  }
}
