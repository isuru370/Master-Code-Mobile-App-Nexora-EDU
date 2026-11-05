class SummaryData {
  final int totalStudents;
  final int presentStudents;
  final int absentStudents;
  final int attendancePercentage;
  final int paidStudents;
  final int unpaidStudents;
  final int paymentPercentage;

  /// Present students marked by scanning the card / by typing the ID
  /// (null: older server).
  final int? qrMarked;
  final int? manualMarked;

  SummaryData({
    required this.totalStudents,
    required this.presentStudents,
    required this.absentStudents,
    required this.attendancePercentage,
    required this.paidStudents,
    required this.unpaidStudents,
    required this.paymentPercentage,
    this.qrMarked,
    this.manualMarked,
  });

  factory SummaryData.fromJson(Map<String, dynamic> json) {
    return SummaryData(
      totalStudents: json['total_students'] ?? 0,
      presentStudents: json['present_students'] ?? 0,
      absentStudents: json['absent_students'] ?? 0,
      attendancePercentage: json['attendance_percentage'] ?? 0,
      paidStudents: json['paid_students'] ?? 0,
      unpaidStudents: json['unpaid_students'] ?? 0,
      paymentPercentage: json['payment_percentage'] ?? 0,
      qrMarked: json['qr_marked'] is int ? json['qr_marked'] as int : null,
      manualMarked: json['manual_marked'] is int ? json['manual_marked'] as int : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_students': totalStudents,
      'present_students': presentStudents,
      'absent_students': absentStudents,
      'attendance_percentage': attendancePercentage,
      'paid_students': paidStudents,
      'unpaid_students': unpaidStudents,
      'payment_percentage': paymentPercentage,
      'qr_marked': qrMarked,
      'manual_marked': manualMarked,
    };
  }
}