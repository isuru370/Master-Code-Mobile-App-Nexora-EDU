class MarkPaymentReceiptItemModel {
  final String className;
  final String grade;
  final String teacherName;
  final String categoryName;
  final String feeOptionName;
  final double classFee;

  /// Hall fee of the class (0 = no hall fee).
  final double hallFee;
  final String receiptNumber;

  /// Amount actually paid (the entered amount, hall fee included).
  final double? paidAmount;

  const MarkPaymentReceiptItemModel({
    required this.className,
    required this.grade,
    required this.teacherName,
    required this.categoryName,
    required this.feeOptionName,
    required this.classFee,
    this.hallFee = 0,
    required this.receiptNumber,
    this.paidAmount,
  });

  factory MarkPaymentReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return MarkPaymentReceiptItemModel(
      className: json['class_name']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? '',
      feeOptionName: json['fee_option_name']?.toString() ?? '',
      classFee: double.tryParse(json['class_fee']?.toString() ?? '0') ?? 0.0,
      hallFee: double.tryParse(json['hall_fee']?.toString() ?? '0') ?? 0.0,
      receiptNumber: json['receipt_no']?.toString() ?? '',
      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? ''),
    );
  }
}
