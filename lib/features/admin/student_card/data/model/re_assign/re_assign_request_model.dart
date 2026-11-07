class ReAssignRequestModel {
  final String oldQrCode;
  final String newQrCode;
  final String reason;
  final String? remarks;

  /// Card fee: an Admissions item ticked "Use for card replacement"
  final int? admissionId;
  final String paymentMethod;

  const ReAssignRequestModel({
    required this.oldQrCode,
    required this.newQrCode,
    required this.reason,
    this.remarks,
    this.admissionId,
    this.paymentMethod = 'cash',
  });

  Map<String, dynamic> toJson() {
    return {
      'old_qr_code': oldQrCode,
      'new_qr_code': newQrCode,
      'reason': reason,
      'remarks': remarks,
      if (admissionId != null) 'admission_id': admissionId,
      if (admissionId != null) 'payment_method': paymentMethod,
    };
  }
}
