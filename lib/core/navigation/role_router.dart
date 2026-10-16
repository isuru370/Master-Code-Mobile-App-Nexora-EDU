/// Which screen each role opens after login / on app start.
class RoleRouter {
  static const String signIn = '/signin';
  static const String staffHome = '/dashboard';
  static const String teacherHome = '/teacher-dashboard';

  static const List<String> staffRoles = [
    'SUPER_ADMIN',
    'ADMIN',
    'BRANCH_ADMIN',
    'USER',
  ];

  /// Route name for the role, or null when the app has no screen for it.
  static String? homeRouteFor(String role) {
    final code = role.trim().toUpperCase();

    if (code == 'TEACHER') return teacherHome;
    if (staffRoles.contains(code)) return staffHome;

    return null;
  }
}