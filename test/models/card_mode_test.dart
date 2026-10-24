import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/features/admin/dashboard/data/models/mobile_dashboard_response_model.dart';

/// The dashboard answer says how the institute gives ID cards.
void main() {
  test('card_mode and card features are read', () {
    final data = MobileDashboardData.fromJson({
      'role': 'USER',
      'card_mode': 'permanent',
      'features': ['register_student', 'register_permanent'],
    });

    expect(data.cardMode, 'permanent');
    expect(data.can('register_permanent'), isTrue);
    expect(data.can('reassign_card'), isFalse);
  });

  test('old backend: no card_mode', () {
    final data = MobileDashboardData.fromJson({'role': 'ADMIN'});

    expect(data.cardMode, isNull);
    expect(data.can('reassign_card'), isTrue, reason: 'no features -> show all');
  });
}
