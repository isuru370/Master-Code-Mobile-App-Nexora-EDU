import 'branch_model.dart';
import 'session_teacher_model.dart';
import 'user_model.dart';

/// Response of POST /api/login (and GET /api/me, which has no token).
class LoginResponseModel {
  final String status;
  final String message;

  /// Empty for /api/me (the saved token is kept).
  final String token;

  final UserModel user;

  /// SUPER_ADMIN | ADMIN | BRANCH_ADMIN | USER | TEACHER
  final String role;

  /// "staff" or "teacher" - which part of the app to open
  final String home;

  /// true for SUPER_ADMIN / ADMIN (they see every branch)
  final bool allBranches;

  final List<BranchModel> branches;

  /// Only for TEACHER
  final SessionTeacherModel? teacher;

  const LoginResponseModel({
    required this.status,
    required this.message,
    required this.token,
    required this.user,
    required this.role,
    required this.home,
    required this.allBranches,
    required this.branches,
    this.teacher,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final user = UserModel.fromJson(
      (json['user'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );

    // Older servers send no "role" - fall back to user.user_type.code
    final role = (json['role'] ?? user.userType?.code ?? '')
        .toString()
        .toUpperCase();

    return LoginResponseModel(
      status: (json['status'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      user: user,
      role: role,
      home: (json['home'] ?? (role == 'TEACHER' ? 'teacher' : 'staff'))
          .toString(),
      allBranches: json['all_branches'] == true,
      branches: BranchModel.listFromJson(json['branches']),
      teacher: json['teacher'] is Map<String, dynamic>
          ? SessionTeacherModel.fromJson(
              json['teacher'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}