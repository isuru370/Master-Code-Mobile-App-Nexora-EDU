import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/session_storage.dart';

/// DELETE /api/payments/{id} {reason}: Admin deletes a wrong payment.
/// Soft delete on the server (kept with the reason); the class and month
/// can then be paid again. Returns the server's message.
class PaymentDeleteApi {
  const PaymentDeleteApi();

  Future<String> delete({required int paymentId, required String reason}) async {
    final token = await SessionStorage.getToken();

    final http.Response response;
    try {
      response = await http.delete(
        Uri.parse('${ApiConstants.apiUrl}/payments/$paymentId'),
        headers: ApiConstants.headers(token: token),
        body: jsonEncode({'reason': reason.trim()}),
      );
    } on http.ClientException catch (e) {
      throw PaymentDeleteException(e.message);
    }

    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // keep the empty body
    }

    final message = body['message']?.toString() ?? '';

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return message.isNotEmpty ? message : 'Payment deleted.';
    }

    if (response.statusCode == 403) {
      throw const PaymentDeleteException('Only an Admin can delete a payment.');
    }

    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        throw PaymentDeleteException(first.first.toString());
      }
    }

    throw PaymentDeleteException(
        message.isNotEmpty ? message : 'Could not delete the payment. Please try again.');
  }
}

class PaymentDeleteException implements Exception {
  final String message;
  const PaymentDeleteException(this.message);

  @override
  String toString() => message;
}
