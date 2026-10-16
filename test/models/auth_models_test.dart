import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/features/auth/data/models/branch_model.dart';
import 'package:nexorait_education_app/features/auth/data/models/login_response_model.dart';

void main() {
  group('BranchModel.listFromJson', () {
    test('parses a list and ignores bad items', () {
      final list = BranchModel.listFromJson([
        {'id': 1, 'name': 'Main', 'code': 'MN'},
        {'id': '2', 'name': 'Kandy'},
        'not a map',
      ]);
      expect(list.length, 2);
      expect(list[0].code, 'MN');
      expect(list[1].id, 2);
      expect(list[1].code, isNull);
    });

    test('anything that is not a list gives an empty list', () {
      expect(BranchModel.listFromJson(null), isEmpty);
      expect(BranchModel.listFromJson({'id': 1}), isEmpty);
    });
  });

  group('LoginResponseModel.fromJson', () {
    test('new backend: role, branches, home', () {
      final m = LoginResponseModel.fromJson({
        'status': 'success',
        'token': 'abc',
        'role': 'branch_admin',
        'all_branches': false,
        'branches': [
          {'id': 3, 'name': 'Galle', 'code': 'GL'},
        ],
        'user': {'id': 9, 'name': 'Nimal', 'email': 'n@x.lk', 'is_active': 1},
      });
      expect(m.token, 'abc');
      expect(m.role, 'BRANCH_ADMIN');
      expect(m.home, 'staff');
      expect(m.allBranches, isFalse);
      expect(m.branches.single.name, 'Galle');
      expect(m.user.isActive, isTrue);
      expect(m.teacher, isNull);
    });

    test('old backend: role comes from user.user_type.code', () {
      final m = LoginResponseModel.fromJson({
        'token': 't',
        'user': {
          'id': 1,
          'name': 'T',
          'email': 't@x.lk',
          'user_type': {'id': 5, 'name': 'Teacher', 'code': 'teacher'},
        },
      });
      expect(m.role, 'TEACHER');
      expect(m.home, 'teacher');
      expect(m.branches, isEmpty);
    });

    test('/me response without a token or user does not crash', () {
      final m = LoginResponseModel.fromJson({});
      expect(m.token, '');
      expect(m.role, '');
      expect(m.user.id, 0);
    });
  });
}
