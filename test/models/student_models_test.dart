import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/features/admin/students/data/models/create_student/create_student_response_model.dart';
import 'package:nexorait_education_app/features/admin/students/data/models/students_model.dart';
import 'package:nexorait_education_app/features/admin/student_card/data/model/student_card_response_model.dart';

Map<String, dynamic> _student(dynamic admission) => {
      'id': 1,
      'initial_name': 'A. Perera',
      'gender': 'male',
      'guardian_mobile': '0771234567',
      'grade_id': '10',
      'admission': admission,
    };

void main() {
  group('StudentModel.admissionPaid', () {
    test('reads 1 / "1" / true as paid', () {
      expect(StudentModel.fromJson(_student(1)).admissionPaid, isTrue);
      expect(StudentModel.fromJson(_student('1')).admissionPaid, isTrue);
      expect(StudentModel.fromJson(_student(true)).admissionPaid, isTrue);
    });

    test('reads 0 / false as not paid, null as unknown', () {
      expect(StudentModel.fromJson(_student(0)).admissionPaid, isFalse);
      expect(StudentModel.fromJson(_student(false)).admissionPaid, isFalse);
      expect(StudentModel.fromJson(_student(null)).admissionPaid, isNull);
    });

    test('string ids are parsed', () {
      expect(StudentModel.fromJson(_student(1)).gradeId, 10);
    });
  });

  group('AdmissionPaymentPrintModel', () {
    test('fromJson / toJson round trip, amount kept as text', () {
      final json = {
        'id': 7,
        'receipt_number': 'ADM-0007',
        'amount': 1500.5,
        'status': 'paid',
        'paid_at': '2026-10-16 09:30',
        'payment_method': 'cash',
        'admission_name': 'Admission 2026',
      };
      final m = AdmissionPaymentPrintModel.fromJson(json);
      expect(m.amount, '1500.5');
      expect(m.receiptNumber, 'ADM-0007');
      expect(AdmissionPaymentPrintModel.fromJson(m.toJson()).toJson(), m.toJson());
    });
  });

  group('StudentCardResponseModel branch fields', () {
    test('reads card.branch_id and card.branch', () {
      final m = StudentCardResponseModel.fromJson({
        'status': true,
        'message': 'ok',
        'card': {'branch_id': '4', 'branch': 'Matara'},
      });
      expect(m.cardBranchId, 4);
      expect(m.cardBranchName, 'Matara');
    });

    test('no card -> branch fields are null', () {
      final m = StudentCardResponseModel.fromJson({'status': false, 'message': ''});
      expect(m.cardBranchId, isNull);
      expect(m.cardBranchName, isNull);
    });
  });
}
