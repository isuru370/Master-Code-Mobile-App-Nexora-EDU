import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/session_storage.dart';

/// One class + one month on the payment screen (POST /api/new-payment/month-info):
/// attendance that month, the fee after the institute's Payment Rules,
/// already paid or not, and that month's tute.
///
/// The rules are set per institute (web: Payment Rules, Super Admin) and are
/// all off by default; then this only shows the attendance count.
/// Fee options: the cashier picks e.g. "Half" for this month only.
class PaymentFeeOption {
  const PaymentFeeOption({
    required this.id,
    required this.label,
    required this.amount,
    required this.isStudentOption,
  });

  final int id;
  final String label;

  /// What the month costs with this option (hall fee added).
  final double amount;

  /// The student's own option (selected first).
  final bool isStudentOption;

  factory PaymentFeeOption.fromJson(Map<String, dynamic> json) => PaymentFeeOption(
        id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
        label: json['label']?.toString() ?? '',
        amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
        isStudentOption: json['is_student_option'] == true,
      );
}

class PaymentMonthInfo {
  const PaymentMonthInfo({
    required this.enrollmentId,
    required this.monthName,
    required this.attendanceCount,
    required this.noAttendance,
    required this.grossFee,
    required this.feeOptionEnabled,
    required this.feeOptions,
    required this.customAmount,
    required this.alreadyPaid,
    required this.paidReceipt,
    required this.tuteEnabled,
    required this.tuteIssued,
    required this.tuteIssuedAt,
  });

  final int enrollmentId;
  final String monthName;
  final int attendanceCount;

  /// Institute rule: no attendance this month, so no payment is taken.
  final bool noAttendance;

  final double grossFee;

  /// Cashier picks one of the class category's fee options for this month.
  final bool feeOptionEnabled;
  final List<PaymentFeeOption> feeOptions;

  /// Cashier may type the amount (the rest is saved as a discount).
  final bool customAmount;

  final bool alreadyPaid;
  final String? paidReceipt;

  final bool tuteEnabled;
  final bool tuteIssued;
  final String? tuteIssuedAt;

  PaymentFeeOption? get studentOption {
    for (final option in feeOptions) {
      if (option.isStudentOption) return option;
    }
    return feeOptions.isNotEmpty ? feeOptions.first : null;
  }

  static double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  factory PaymentMonthInfo.fromJson(Map<String, dynamic> json) {
    final tute = json['tute'] is Map ? json['tute'] as Map : const {};
    final paid = json['paid'] is Map ? json['paid'] as Map : null;
    final options = json['fee_options'] is List ? json['fee_options'] as List : const [];

    return PaymentMonthInfo(
      enrollmentId: int.tryParse(json['enrollment_id']?.toString() ?? '') ?? 0,
      monthName: json['payment_month_name']?.toString() ?? '',
      attendanceCount: int.tryParse(json['attendance_count']?.toString() ?? '') ?? 0,
      noAttendance: json['no_attendance'] == true,
      grossFee: _num(json['gross_fee']),
      feeOptionEnabled: json['fee_option_enabled'] == true,
      feeOptions: options
          .whereType<Map<String, dynamic>>()
          .map(PaymentFeeOption.fromJson)
          .toList(),
      customAmount: json['custom_amount'] == true,
      alreadyPaid: json['already_paid'] == true,
      paidReceipt: paid?['receipt_number']?.toString(),
      tuteEnabled: tute['enabled'] == true,
      tuteIssued: tute['issued'] == true,
      tuteIssuedAt: tute['issued_at']?.toString(),
    );
  }

  /// Null when it could not be loaded (old server, no network): the payment
  /// screen then works as before.
  static Future<PaymentMonthInfo?> fetch({
    required String code,
    required int enrollmentId,
    required String paymentMonth,
  }) async {
    try {
      final token = await SessionStorage.getToken();

      final response = await http.post(
        Uri.parse('${ApiConstants.apiUrl}/new-payment/month-info'),
        headers: ApiConstants.headers(token: token),
        body: jsonEncode({
          'code': code,
          'enrollment_id': enrollmentId,
          'payment_month': paymentMonth,
        }),
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      final data = body is Map ? body['data'] : null;
      if (data is! Map<String, dynamic>) return null;

      return PaymentMonthInfo.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
