import 'read_attendance_model.dart';
import 'read_last_payment_model.dart';

class ReadStudentClassPaymentModel {
  final int enrollmentId;
  final int studentClassId;
  final int classCategoryId;
  final String className;
  final String categoryName;
  final String teacherInitials;
  final String grade;
  final String subject;
  final bool isFreeCard;

  /// What to pay: class fee + hall fee (server sends it with the hall fee).
  final double finalFee;

  /// Class fee only (older servers: same as finalFee).
  final double classFee;

  /// Hall fee of the class (0 = none).
  final double hallFee;
  final ReadLastPaymentModel? lastPayment;
  final ReadAttendanceModel? attendance;

  ReadStudentClassPaymentModel({
    required this.enrollmentId,
    required this.studentClassId,
    required this.classCategoryId,
    required this.className,
    required this.categoryName,
    required this.teacherInitials,
    required this.grade,
    required this.subject,
    required this.isFreeCard,
    required this.finalFee,
    double? classFee,
    this.hallFee = 0,
    required this.lastPayment,
    required this.attendance,
  }) : classFee = classFee ?? finalFee;

  factory ReadStudentClassPaymentModel.fromJson(Map<String, dynamic> json) {
    return ReadStudentClassPaymentModel(
      enrollmentId: json['enrollment_id'] ?? 0,
      studentClassId: json['student_class_id'] ?? 0,
      classCategoryId: json['class_category_id'] ?? 0,
      className: json['class_name'] ?? '',
      categoryName: json['category_name'] ?? '',
      teacherInitials: json['teacher_initials'] ?? '',
      grade: json['grade']?.toString() ?? '',
      subject: json['subject'] ?? '',
      isFreeCard: json['is_free_card'] ?? false,
      finalFee: _toDouble(json['final_fee']),
      classFee: json['class_fee'] == null ? null : _toDouble(json['class_fee']),
      hallFee: _toDouble(json['hall_fee']),
      lastPayment: json['last_payment'] != null
          ? ReadLastPaymentModel.fromJson(
              json['last_payment'] as Map<String, dynamic>,
            )
          : null,
      attendance: json['attendance'] != null
          ? ReadAttendanceModel.fromJson(
              json['attendance'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}