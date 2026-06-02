import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/enrollment/data/models/enrollment_model.dart';

void main() {
  test('preserves UUID club enrollment id for UUID-based endpoints', () {
    final enrollment = EnrollmentModel.fromJson({
      'club_enrollment_id': '46bebcb7-3f0a-49c7-930a-a25efc9bde89',
      'club_section_id': 12,
      'year': 2026,
      'created_by': 'user-1',
      'status': 'active',
      'meeting_days': 'Sábado',
    });

    expect(enrollment.id, 0);
    expect(enrollment.enrollmentUuid, '46bebcb7-3f0a-49c7-930a-a25efc9bde89');
  });
}
