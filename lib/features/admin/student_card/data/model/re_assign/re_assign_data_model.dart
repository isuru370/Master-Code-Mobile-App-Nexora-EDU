class ReAssignDataModel {
  final int cardId;
  final String cardNumber;
  final String qrCode;
  final int studentId;
  final String status;

  /// The card fee saved with the re-assign (null when none)
  final ReAssignPaymentModel? payment;

  const ReAssignDataModel({
    required this.cardId,
    required this.cardNumber,
    required this.qrCode,
    required this.studentId,
    required this.status,
    this.payment,
  });

  factory ReAssignDataModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ReAssignDataModel(
      cardId: json['card_id'] ?? 0,
      cardNumber: json['card_number'] ?? '',
      qrCode: json['qr_code'] ?? '',
      studentId: json['student_id'] ?? 0,
      status: json['status'] ?? '',
      payment: json['payment'] is Map<String, dynamic>
          ? ReAssignPaymentModel.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ReAssignPaymentModel {
  final String receiptNumber;
  final String item;
  final double amount;
  final String paymentMethod;
  final String paidAt;
  final String studentCustomId;
  final String studentName;

  const ReAssignPaymentModel({
    required this.receiptNumber,
    required this.item,
    required this.amount,
    required this.paymentMethod,
    required this.paidAt,
    required this.studentCustomId,
    required this.studentName,
  });

  factory ReAssignPaymentModel.fromJson(Map<String, dynamic> json) {
    return ReAssignPaymentModel(
      receiptNumber: json['receipt_number']?.toString() ?? '',
      item: json['item']?.toString() ?? '',
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      paidAt: json['paid_at']?.toString() ?? '',
      studentCustomId: json['student_custom_id']?.toString() ?? '-',
      studentName: json['student_name']?.toString() ?? '',
    );
  }
}
