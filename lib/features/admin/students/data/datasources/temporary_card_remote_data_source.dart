import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/storage/session_storage.dart';

/// The temporary card the next registered student will get
/// (GET /api/temporary-cards/next). The server gives the lowest-numbered
/// ISSUED card automatically.
class NextTemporaryCard {
  const NextTemporaryCard({this.next, this.issuedLeft = 0, this.message});

  /// e.g. "TMP045"; null when no issued cards are left
  final String? next;
  final int issuedLeft;
  final String? message;
}

class TemporaryCardRemoteDataSource {
  /// null when the server could not be asked (old server, offline ...)
  Future<NextTemporaryCard?> next() async {
    try {
      final token = await SessionStorage.getToken();
      final response = await http.get(
        Uri.parse('${ApiConstants.apiUrl}/temporary-cards/next'),
        headers: ApiConstants.headers(token: token),
      );

      if (response.statusCode != 200) return null;

      final data = (jsonDecode(response.body) as Map<String, dynamic>)['data'];
      if (data is! Map<String, dynamic>) return null;

      return NextTemporaryCard(
        next: data['next']?.toString(),
        issuedLeft: int.tryParse('${data['issued_left'] ?? 0}') ?? 0,
        message: data['message']?.toString(),
      );
    } catch (e) {
      debugPrint('NEXT TEMPORARY CARD ERROR: $e');
      return null;
    }
  }
}
