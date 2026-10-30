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
class PaymentMonthInfo {
  const PaymentMonthInfo({
    required this.enrollmentId,
    required this.monthName,
    required this.attendanceCount,
    required this.grossFee,
    required this.ruleEnabled,
    required this.rulePercent,
    required this.ruleReason,
    required this.noFee,
    required this.suggestedAmount,
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
  final double grossFee;

  final bool ruleEnabled;
  final int rulePercent;
  final String? ruleReason;
  final bool noFee;
  final double suggestedAmount;

  /// Cashier may type the amount (the rest is saved as a discount).
  final bool customAmount;

  final bool alreadyPaid;
  final String? paidReceipt;

  final bool tuteEnabled;
  final bool tuteIssued;
  final String? tuteIssuedAt;

  /// The amount field can be changed by the cashier.
  bool get amountEditable => customAmount || ruleEnabled;

  static double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  factory PaymentMonthInfo.fromJson(Map<String, dynamic> json) {
    final rule = json['rule'] is Map ? json['rule'] as Map : const {};
    final tute = json['tute'] is Map ? json['tute'] as Map : const {};
    final paid = json['paid'] is Map ? json['paid'] as Map : null;

    return PaymentMonthInfo(
      enrollmentId: int.tryParse(json['enrollment_id']?.toString() ?? '') ?? 0,
      monthName: json['payment_month_name']?.toString() ?? '',
      attendanceCount: int.tryParse(json['attendance_count']?.toString() ?? '') ?? 0,
      grossFee: _num(json['gross_fee']),
      ruleEnabled: rule['enabled'] == true,
      rulePercent: int.tryParse(rule['percent']?.toString() ?? '') ?? 100,
      ruleReason: rule['reason']?.toString(),
      noFee: rule['no_fee'] == true,
      suggestedAmount: _num(json['suggested_amount']),
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
