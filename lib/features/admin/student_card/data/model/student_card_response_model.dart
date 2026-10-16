import 'current_card_model.dart';
import 'student_card_data_model.dart';
import 'student_card_model.dart';
import 'student_mini_model.dart';

class StudentCardResponseModel extends StudentCardDataModel {
  /// Available card only: the branch the card belongs to
  final int? cardBranchId;
  final String? cardBranchName;
  final String? cardNumber;

  const StudentCardResponseModel({
    required super.status,
    required super.message,
    super.student,
    super.currentCard,
    super.cards,
    this.cardBranchId,
    this.cardBranchName,
    this.cardNumber,
  });

  factory StudentCardResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final card = json['card'] is Map
        ? Map<String, dynamic>.from(json['card'] as Map)
        : const <String, dynamic>{};

    return StudentCardResponseModel(
      cardBranchId: int.tryParse(card['branch_id']?.toString() ?? ''),
      cardBranchName: card['branch']?.toString(),
      cardNumber: card['card_number']?.toString(),
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      student: json['student'] == null
          ? null
          : StudentMiniModel.fromJson(json['student']),
      currentCard: json['current_card'] == null
          ? null
          : CurrentCardModel.fromJson(json['current_card']),
      cards: json['cards'] == null
          ? []
          : (json['cards'] as List)
              .map((e) => StudentCardModel.fromJson(e))
              .toList(),
    );
  }
}