import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/storage/session_storage.dart';

/// A card replacement fee (Admissions item ticked "Use for card replacement")
class CardFeeItem {
  const CardFeeItem({required this.id, required this.name, required this.amount});

  final int id;
  final String name;
  final double amount;

  String get label => amount > 0 ? '$name - Rs. ${amount.toStringAsFixed(2)}' : '$name - Free';
}

class CardFeeRemoteDataSource {
  /// GET /api/card-replacement-fees. Empty list when none or old server.
  Future<List<CardFeeItem>> fetch() async {
    try {
      final token = await SessionStorage.getToken();
      final response = await http.get(
        Uri.parse('${ApiConstants.apiUrl}/card-replacement-fees'),
        headers: ApiConstants.headers(token: token),
      );

      if (response.statusCode != 200) return const [];

      final data = (jsonDecode(response.body) as Map<String, dynamic>)['data'];
      if (data is! List) return const [];

      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => CardFeeItem(
                id: int.tryParse('${item['id']}') ?? 0,
                name: item['name']?.toString() ?? '',
                amount: double.tryParse('${item['amount'] ?? 0}') ?? 0,
              ))
          .where((item) => item.id > 0)
          .toList();
    } catch (e) {
      debugPrint('CARD FEES ERROR: $e');
      return const [];
    }
  }
}
