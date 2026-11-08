import 'package:intl/intl.dart';

class TodayPaymentsRequestModel {
  final DateTime date;

  /// Student name or ID (also card number, mobile, class)
  final String? search;

  final int page;
  final int perPage;

  TodayPaymentsRequestModel({
    required this.date,
    this.search,
    this.page = 1,
    this.perPage = 50,
  });

  TodayPaymentsRequestModel copyWith({int? page}) {
    return TodayPaymentsRequestModel(
      date: date,
      search: search,
      page: page ?? this.page,
      perPage: perPage,
    );
  }

  Map<String, dynamic> toJson() {
    final text = search?.trim() ?? '';

    return {
      'date': DateFormat('yyyy-MM-dd').format(date),
      if (text.isNotEmpty) 'search': text,
      'page': page,
      'per_page': perPage,
    };
  }
}
