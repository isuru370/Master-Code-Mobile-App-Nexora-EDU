import 'today_payment_item_model.dart';
import 'today_payment_summary_model.dart';

class TodayPaymentsResponseModel {
  final bool success;
  final List<TodayPaymentItemModel> data;
  final TodayPaymentSummaryModel summary;

  final String date;
  final String? search;

  final int total;

  final int lastPage;

  const TodayPaymentsResponseModel({
    required this.success,
    required this.data,
    required this.summary,
    required this.date,
    required this.search,
    required this.total,
    this.lastPage = 1,
  });

  /// The same response with more rows (the next pages)
  TodayPaymentsResponseModel withMoreData(List<TodayPaymentItemModel> more) {
    return TodayPaymentsResponseModel(
      success: success,
      data: [...data, ...more],
      summary: summary,
      date: date,
      search: search,
      total: total,
      lastPage: lastPage,
    );
  }

  factory TodayPaymentsResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final filters =
        json['filters'] as Map<String, dynamic>? ?? {};

    final meta =
        json['meta'] as Map<String, dynamic>? ?? {};

    return TodayPaymentsResponseModel(
      success: json['success'] == true,

      data: (json['data'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TodayPaymentItemModel.fromJson)
          .toList(),

      summary: TodayPaymentSummaryModel.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),

      date: filters['date']?.toString() ?? '',

      search: filters['search']?.toString(),

      total: int.tryParse(
            meta['total']?.toString() ?? '0',
          ) ??
          0,

      lastPage: int.tryParse(
            meta['last_page']?.toString() ?? '1',
          ) ??
          1,
    );
  }
}