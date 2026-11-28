import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/offline/offline_engine.dart';
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

/// Payment Rules > multi-class discount: [amount] off each class fee when at
/// least [minClasses] different classes are paid at once.
class MultiClassRule {
  const MultiClassRule({required this.enabled, required this.minClasses, required this.amount});

  static const off = MultiClassRule(enabled: false, minClasses: 0, amount: 0);

  final bool enabled;
  final int minClasses;
  final double amount;

  factory MultiClassRule.fromJson(dynamic json) {
    if (json is! Map) return off;
    final min = int.tryParse(json['min_classes']?.toString() ?? '') ?? 0;
    final amount = double.tryParse(json['amount']?.toString() ?? '') ?? 0;
    return MultiClassRule(enabled: json['enabled'] == true && min >= 2 && amount > 0, minClasses: min, amount: amount);
  }
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
    this.classFee = 0,
    this.branchId = 0,
    this.countsForMultiClass = false,
    this.multiClass = MultiClassRule.off,
  });

  /// Class fee only (the multi-class discount comes off it, not the hall fee).
  final double classFee;
  final int branchId;

  /// Not a free card and has a fee: counts for the multi-class discount.
  final bool countsForMultiClass;

  /// Payment Rules > multi-class discount (several classes paid at once).
  final MultiClassRule multiClass;

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
      classFee: _num(json['class_fee']),
      branchId: int.tryParse(json['branch_id']?.toString() ?? '') ?? 0,
      countsForMultiClass: json['counts_for_multi_class'] == true,
      multiClass: MultiClassRule.fromJson(json['multi_class_discount']),
    );
  }

  /// The multi-class discount of each class paid together (enrollment id =>
  /// LKR), as the server works it out: classes that count, per branch, at
  /// least the rule's number of classes; never more than the class fee.
  /// [paying] = the enrollments sent (amount above 0).
  static Map<int, double> multiClassDiscounts(Iterable<PaymentMonthInfo> paying) {
    final infos = paying.where((i) => i.countsForMultiClass && i.classFee > 0).toList();
    if (infos.isEmpty) return const {};
    final rule = infos.first.multiClass;
    if (!rule.enabled) return const {};

    final perBranch = <int, int>{};
    for (final info in infos) {
      perBranch[info.branchId] = (perBranch[info.branchId] ?? 0) + 1;
    }

    return {
      for (final info in infos)
        if ((perBranch[info.branchId] ?? 0) >= rule.minClasses)
          info.enrollmentId: rule.amount < info.classFee ? rule.amount : info.classFee,
    };
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

      final http.Response response;
      try {
        response = await http
            .post(
              Uri.parse('${ApiConstants.apiUrl}/new-payment/month-info'),
              headers: ApiConstants.headers(token: token),
              body: jsonEncode({
                'code': code,
                'enrollment_id': enrollmentId,
                'payment_month': paymentMonth,
              }),
            )
            .timeout(OfflineEngine.timeout);
      } catch (e) {
        if (!OfflineEngine.isNetworkError(e)) rethrow;
        // no internet: fee, fee options and "already paid" from today's offline data
        return PaymentMonthInfo.fromJson(
          await OfflineEngine.monthInfo(code: code, enrollmentId: enrollmentId, paymentMonth: paymentMonth),
        );
      }

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
