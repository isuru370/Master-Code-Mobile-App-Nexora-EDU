import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/session_storage.dart';

/// GET /api/reports/income?from=yyyy-MM-dd&to=yyyy-MM-dd[&branch_id=]
/// Money in / out for a date range (all staff, own branches).
class IncomeReportApi {
  const IncomeReportApi();

  static final DateFormat _day = DateFormat('yyyy-MM-dd');

  Future<IncomeReport> load({
    required DateTime from,
    required DateTime to,
    int? branchId,
  }) async {
    final token = await SessionStorage.getToken();
    final query = {
      'from': _day.format(from),
      'to': _day.format(to),
      if (branchId != null) 'branch_id': '$branchId',
    };
    final uri = Uri.parse('${ApiConstants.apiUrl}/reports/income')
        .replace(queryParameters: query);

    final http.Response response;
    try {
      response = await http.get(uri, headers: ApiConstants.headers(token: token));
    } on http.ClientException catch (e) {
      throw IncomeReportException(e.message);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const IncomeReportException(
          'The server sent an unexpected response. Please try again.');
    }
    final body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return IncomeReport.fromJson(_map(body['data']));
    }

    if (response.statusCode == 404) {
      throw const IncomeReportException(
          'Income Report is not on the server yet. Please update the server.');
    }
    if (response.statusCode == 403) {
      throw const IncomeReportException('You do not have access to this report.');
    }

    final message = body['message']?.toString() ?? '';
    throw IncomeReportException(
        message.isNotEmpty ? message : 'Something went wrong. Please try again.');
  }
}

class IncomeReportException implements Exception {
  final String message;
  const IncomeReportException(this.message);

  @override
  String toString() => message;
}

/* ------------------------------- Models ---------------------------------- */

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<Map<String, dynamic>> _list(dynamic value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

String _str(dynamic value) => value?.toString() ?? '';

/// count + amount
class IncomeLine {
  final int count;
  final double amount;

  const IncomeLine(this.count, this.amount);

  factory IncomeLine.fromJson(dynamic json) {
    final map = _map(json);
    return IncomeLine(_int(map['count']), _num(map['amount']));
  }
}

class IncomeReport {
  final DateTime from;
  final DateTime to;
  final String branch;
  final IncomeLine classFees;
  final double hallFee;
  final int hallFeeCount;

  /// payment method => amount (class fees)
  final Map<String, double> classFeesByMethod;

  /// null when the institute has no courses
  final IncomeLine? courseFees;
  final IncomeLine admission;
  final IncomeLine extraIncome;
  final double totalIncome;

  final IncomeLine expenses;
  final IncomeLine teacherAdvances;
  final double totalExpenses;

  final double net;

  final List<IncomeDay> days;
  final List<IncomeItem> expenseItems;
  final List<IncomeItem> advanceItems;
  final List<IncomeItem> extraItems;

  const IncomeReport({
    required this.from,
    required this.to,
    required this.branch,
    required this.classFees,
    required this.hallFee,
    required this.hallFeeCount,
    required this.classFeesByMethod,
    required this.courseFees,
    required this.admission,
    required this.extraIncome,
    required this.totalIncome,
    required this.expenses,
    required this.teacherAdvances,
    required this.totalExpenses,
    required this.net,
    required this.days,
    required this.expenseItems,
    required this.advanceItems,
    required this.extraItems,
  });

  bool get isOneDay =>
      from.year == to.year && from.month == to.month && from.day == to.day;

  factory IncomeReport.fromJson(Map<String, dynamic> json) {
    final income = _map(json['income']);
    final classFees = _map(income['class_fees']);
    final out = _map(json['expenses']);
    final byMethod = _map(classFees['by_method']);

    return IncomeReport(
      from: DateTime.tryParse(_str(json['from'])) ?? DateTime.now(),
      to: DateTime.tryParse(_str(json['to'])) ?? DateTime.now(),
      branch: _str(json['branch']),
      classFees: IncomeLine.fromJson(classFees),
      hallFee: _num(classFees['hall_fee']),
      hallFeeCount: _int(classFees['hall_fee_count']),
      classFeesByMethod: byMethod.map((k, v) => MapEntry(k, _num(v))),
      courseFees: income['course_fees'] == null ? null : IncomeLine.fromJson(income['course_fees']),
      admission: IncomeLine.fromJson(income['admission']),
      extraIncome: IncomeLine.fromJson(income['extra_income']),
      totalIncome: _num(income['total']),
      expenses: IncomeLine.fromJson(out['institute']),
      teacherAdvances: IncomeLine.fromJson(out['teacher_advances']),
      totalExpenses: _num(out['total']),
      net: _num(json['net']),
      days: _list(json['days']).map(IncomeDay.fromJson).toList(),
      expenseItems: _list(json['expense_items']).map((e) => IncomeItem.fromJson(e, 'reason')).toList(),
      advanceItems: _list(json['advance_items']).map((e) => IncomeItem.fromJson(e, 'teacher')).toList(),
      extraItems: _list(json['extra_items']).map((e) => IncomeItem.fromJson(e, 'reason')).toList(),
    );
  }
}

class IncomeDay {
  final String date;
  final double classFees;
  final double courseFees;
  final double admission;
  final double extraIncome;
  final double expenses;
  final double teacherAdvances;
  final double income;
  final double out;
  final double net;

  const IncomeDay({
    required this.date,
    required this.classFees,
    required this.courseFees,
    required this.admission,
    required this.extraIncome,
    required this.expenses,
    required this.teacherAdvances,
    required this.income,
    required this.out,
    required this.net,
  });

  factory IncomeDay.fromJson(Map<String, dynamic> json) => IncomeDay(
        date: _str(json['date']),
        classFees: _num(json['class_fees']),
        courseFees: _num(json['course_fees']),
        admission: _num(json['admission']),
        extraIncome: _num(json['extra_income']),
        expenses: _num(json['expenses']),
        teacherAdvances: _num(json['teacher_advances']),
        income: _num(json['income']),
        out: _num(json['out']),
        net: _num(json['net']),
      );
}

/// An expense, advance or extra income line.
class IncomeItem {
  final String date;
  final String title;
  final String note;
  final double amount;

  const IncomeItem({
    required this.date,
    required this.title,
    required this.note,
    required this.amount,
  });

  factory IncomeItem.fromJson(Map<String, dynamic> json, String titleKey) => IncomeItem(
        date: _str(json['date']),
        title: _str(json[titleKey]),
        note: _str(json['note']),
        amount: _num(json['amount']),
      );
}
