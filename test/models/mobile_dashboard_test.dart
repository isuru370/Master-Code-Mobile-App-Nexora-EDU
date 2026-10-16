import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/features/admin/dashboard/data/models/mobile_dashboard_response_model.dart';

void main() {
  group('MobileDashboardData.fromJson', () {
    test('empty json does not crash and gives zeros', () {
      final d = MobileDashboardData.fromJson({});
      expect(d.totalStudent, 0);
      expect(d.todayTotalCollection, 0);
      expect(d.smsBalance, isNull);
      expect(d.finance, isNull);
      expect(d.branch, isNull);
      expect(d.features, isEmpty);
    });

    test('old backend: sections are filled from flat values', () {
      final d = MobileDashboardData.fromJson({
        'total_student': '120',
        'permanent_student_count': 100,
        'temporary_student_count': 20,
        'today_payment_collection': '2500.00',
        'today_admission_collection': 500,
      });
      expect(d.students.total, 120);
      expect(d.students.permanent, 100);
      expect(d.todayTotalCollection, 3000);
      expect(d.collection.todayTotal, 3000);
    });

    test('features: empty = show everything, otherwise only listed', () {
      expect(MobileDashboardData.fromJson({}).can('payment'), isTrue);
      final d = MobileDashboardData.fromJson({
        'role': 'user',
        'features': ['payment'],
      });
      expect(d.isCashier, isTrue);
      expect(d.can('payment'), isTrue);
      expect(d.can('class_schedule'), isFalse);
    });

    test('branch and branches are parsed', () {
      final d = MobileDashboardData.fromJson({
        'role': 'BRANCH_ADMIN',
        'branch': {'id': 2, 'name': 'Kandy', 'code': 'KD'},
        'branches': [
          {'id': 2, 'name': 'Kandy'},
          {'id': 3, 'name': 'Galle'},
        ],
      });
      expect(d.isBranchAdmin, isTrue);
      expect(d.branch?.code, 'KD');
      expect(d.branches.length, 2);
    });
  });
}
