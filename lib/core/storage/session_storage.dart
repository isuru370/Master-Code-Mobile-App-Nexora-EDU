import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/models/branch_model.dart';
import '../../features/auth/data/models/login_response_model.dart';
import '../../features/auth/data/models/session_teacher_model.dart';
import '../../features/auth/data/models/user_model.dart';

/// Everything the app keeps about the logged-in user.
///
/// Saved from POST /api/login (and later GET /api/me):
///   token, user, role, home ("staff" / "teacher"), branches, teacher
/// plus the branch the user picked in the app (selected branch).
class SessionStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _roleKey = 'auth_role';
  static const String _homeKey = 'auth_home';
  static const String _allBranchesKey = 'auth_all_branches';
  static const String _branchesKey = 'auth_branches';
  static const String _teacherKey = 'auth_teacher';
  static const String _selectedBranchKey = 'auth_selected_branch_id';
  static const String _emailKey = 'remember_email';

  /// Roles that open the staff part of the app
  static const List<String> staffRoles = [
    'SUPER_ADMIN',
    'ADMIN',
    'BRANCH_ADMIN',
    'USER',
  ];

  static const String teacherRole = 'TEACHER';

  /*
  |--------------------------------------------------------------------------
  | Save
  |--------------------------------------------------------------------------
  */

  /// Save the whole login (or /me) response.
  /// A response without a token (/me) keeps the saved token.
  static Future<void> saveSession(LoginResponseModel session) async {
    final prefs = await SharedPreferences.getInstance();

    if (session.token.isNotEmpty) {
      await prefs.setString(_tokenKey, session.token);
    }

    await prefs.setString(_userKey, jsonEncode(session.user.toJson()));
    await prefs.setString(_roleKey, session.role);
    await prefs.setString(_homeKey, session.home);
    await prefs.setBool(_allBranchesKey, session.allBranches);
    await prefs.setString(
      _branchesKey,
      jsonEncode(session.branches.map((b) => b.toJson()).toList()),
    );

    if (session.teacher != null) {
      await prefs.setString(_teacherKey, jsonEncode(session.teacher!.toJson()));
    } else {
      await prefs.remove(_teacherKey);
    }

    // Forget the picked branch if the user no longer has it
    final selected = prefs.getInt(_selectedBranchKey);
    final branchIds = session.branches.map((b) => b.id).toList();

    if (selected != null && !branchIds.contains(selected)) {
      await prefs.remove(_selectedBranchKey);
    }

    // Save email for next login
    if (session.user.email.isNotEmpty) {
      await prefs.setString(_emailKey, session.user.email);
    }
  }

  /// Old way of saving (token + user only). Kept so older code still works.
  static Future<void> saveAuth({
    required String token,
    required UserModel user,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));

    final role = user.userType?.code.toUpperCase() ?? '';
    await prefs.setString(_roleKey, role);
    await prefs.setString(_homeKey, role == teacherRole ? 'teacher' : 'staff');

    // Save email for next login
    await prefs.setString(_emailKey, user.email);
  }

  /// Remember which branch the user is working in (null = all branches).
  static Future<void> setSelectedBranchId(int? branchId) async {
    final prefs = await SharedPreferences.getInstance();

    if (branchId == null) {
      await prefs.remove(_selectedBranchKey);
    } else {
      await prefs.setInt(_selectedBranchKey, branchId);
    }
  }

  /*
  |--------------------------------------------------------------------------
  | Read
  |--------------------------------------------------------------------------
  */

  /// Get token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.trim().isNotEmpty;
  }

  /// Get logged user (null if nothing saved or the saved data is broken)
  static Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_userKey);
    if (raw == null) return null;

    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// SUPER_ADMIN | ADMIN | BRANCH_ADMIN | USER | TEACHER ('' if unknown)
  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString(_roleKey);
    if (saved != null && saved.isNotEmpty) return saved;

    // Sessions saved by older app versions: read it from the user
    final user = await getUser();
    return user?.userType?.code.toUpperCase() ?? '';
  }

  /// "staff", "teacher" or '' (unknown role)
  static Future<String> getHome() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString(_homeKey);
    if (saved != null && saved.isNotEmpty) return saved;

    final role = await getRole();
    if (role == teacherRole) return 'teacher';
    if (staffRoles.contains(role)) return 'staff';
    return '';
  }

  static Future<bool> isTeacher() async => (await getRole()) == teacherRole;

  static Future<bool> isStaff() async => staffRoles.contains(await getRole());

  /// true for SUPER_ADMIN / ADMIN
  static Future<bool> hasAllBranches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_allBranchesKey) ?? false;
  }

  /// Branches the user can work in
  static Future<List<BranchModel>> getBranches() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_branchesKey);
    if (raw == null) return const [];

    try {
      return BranchModel.listFromJson(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  /// The branch the user is working in.
  /// Only one branch -> that branch. Several and none picked -> null.
  static Future<int?> getSelectedBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    final branches = await getBranches();

    final selected = prefs.getInt(_selectedBranchKey);
    if (selected != null && branches.any((b) => b.id == selected)) {
      return selected;
    }

    return branches.length == 1 ? branches.first.id : null;
  }

  static Future<BranchModel?> getSelectedBranch() async {
    final id = await getSelectedBranchId();
    if (id == null) return null;

    final branches = await getBranches();
    for (final branch in branches) {
      if (branch.id == id) return branch;
    }
    return null;
  }

  /// Teacher profile (TEACHER login only)
  static Future<SessionTeacherModel?> getTeacher() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_teacherKey);
    if (raw == null) return null;

    try {
      return SessionTeacherModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get remembered email
  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  /*
  |--------------------------------------------------------------------------
  | Clear
  |--------------------------------------------------------------------------
  */

  /// Remove only the login session (the remembered email stays
  /// so the sign-in page can fill it in next time)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_homeKey);
    await prefs.remove(_allBranchesKey);
    await prefs.remove(_branchesKey);
    await prefs.remove(_teacherKey);
    await prefs.remove(_selectedBranchKey);
  }

  /// Remove remembered email manually (optional)
  static Future<void> clearSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
  }
}