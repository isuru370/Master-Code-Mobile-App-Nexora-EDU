import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/features/admin/teacher_advance/data/teacher_advance_api.dart';

void main() {
  test('teacher list from GET /api/teacher-advances/teachers', () {
    final list = TeacherAdvanceList.fromJson({
      'branch': {'id': 1, 'name': 'Main Branch'},
      'month': 'October 2026',
      'teachers': [
        {'id': 7, 'custom_id': 'SAT001', 'name': 'Mr. Laknath', 'gross': 45000, 'advance': '5000.00',
         'deductions': 0, 'salary_paid': false, 'available': 40000},
        {'id': 8, 'custom_id': 'SAT002', 'name': 'Ms. Yamuna', 'gross': 1200.5, 'advance': 0,
         'deductions': 0, 'salary_paid': true, 'available': 0},
      ],
    });

    expect(list.branch.name, 'Main Branch');
    expect(list.teachers, hasLength(2));
    expect(list.teachers.first.advance, 5000);
    expect(list.teachers.first.available, 40000);
    expect(list.teachers.last.salaryPaid, isTrue);
  });

  test('slip from POST /api/teacher-advances', () {
    final slip = TeacherAdvanceSlip.fromJson({
      'id': 12,
      'reference': 'ADV-000012',
      'teacher': {'id': 7, 'custom_id': 'SAT001', 'name': 'Mr. Laknath'},
      'branch': {'id': 1, 'name': 'Main Branch'},
      'amount': 5000,
      'reason': 'Transport',
      'note': null,
      'date': '2026-10-28',
      'time': '11:45 AM',
      'month': 'October 2026',
      'paid_by': 'Branch Admin',
      'month_advance_total': 10000,
      'available_after': 35000,
    });

    expect(slip.reference, 'ADV-000012');
    expect(slip.teacherName, 'Mr. Laknath');
    expect(slip.amount, 5000);
    expect(slip.reason, 'Transport');
    expect(slip.note, isNull);
    expect(slip.availableAfter, 35000);
  });
}
