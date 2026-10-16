/// Teacher profile of a TEACHER login (null for staff users).
class SessionTeacherModel {
  final int id;
  final String customId;
  final String fullName;

  const SessionTeacherModel({
    required this.id,
    required this.customId,
    required this.fullName,
  });

  factory SessionTeacherModel.fromJson(Map<String, dynamic> json) {
    return SessionTeacherModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      customId: (json['custom_id'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'custom_id': customId,
      'full_name': fullName,
    };
  }
}