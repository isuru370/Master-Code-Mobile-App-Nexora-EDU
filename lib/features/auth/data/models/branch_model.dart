/// A branch the logged-in user can work in (from /api/login and /api/me).
class BranchModel {
  final int id;
  final String name;
  final String? code;

  const BranchModel({
    required this.id,
    required this.name,
    this.code,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: (json['name'] ?? '').toString(),
      code: json['code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
    };
  }

  /// Safe list parser: anything that is not a list gives an empty list.
  static List<BranchModel> listFromJson(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((e) => BranchModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}