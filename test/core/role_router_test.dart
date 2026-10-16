import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/core/navigation/role_router.dart';

void main() {
  group('RoleRouter.homeRouteFor', () {
    test('teacher opens the teacher dashboard', () {
      expect(RoleRouter.homeRouteFor('TEACHER'), RoleRouter.teacherHome);
      expect(RoleRouter.homeRouteFor(' teacher '), RoleRouter.teacherHome);
    });

    test('staff roles open the staff dashboard', () {
      for (final role in ['SUPER_ADMIN', 'ADMIN', 'BRANCH_ADMIN', 'USER', 'admin']) {
        expect(RoleRouter.homeRouteFor(role), RoleRouter.staffHome, reason: role);
      }
    });

    test('unknown or empty role has no screen', () {
      expect(RoleRouter.homeRouteFor('STUDENT'), isNull);
      expect(RoleRouter.homeRouteFor(''), isNull);
    });
  });
}
