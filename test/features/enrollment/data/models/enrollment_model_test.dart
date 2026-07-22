import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/enrollment/data/models/enrollment_model.dart';
import 'package:sacdia_app/features/enrollment/domain/entities/enrollment.dart';

void main() {
  test('preserves UUID club enrollment id for UUID-based endpoints', () {
    final enrollment = EnrollmentModel.fromJson({
      'club_enrollment_id': '46bebcb7-3f0a-49c7-930a-a25efc9bde89',
      'club_section_id': 12,
      'ecclesiastical_year_id': 2026,
      'created_by': 'user-1',
      'status': 'active',
      'meeting_days': 'Sábado',
      'latitude': 19.4326,
      'longitude': -99.1332,
    });

    expect(enrollment.id, 0);
    expect(enrollment.enrollmentUuid, '46bebcb7-3f0a-49c7-930a-a25efc9bde89');
    expect(enrollment.year, 2026);
    expect(enrollment.lat, 19.4326);
    expect(enrollment.long, -99.1332);
  });

  test('maps pending_validation status from annual club validation flow', () {
    final enrollment = EnrollmentModel.fromJson({
      'club_enrollment_id': '46bebcb7-3f0a-49c7-930a-a25efc9bde89',
      'club_section_id': 12,
      'year': 2026,
      'created_by': 'user-1',
      'status': 'pending_validation',
      'meeting_days': 'Sábado',
    });

    expect(enrollment.status, EnrollmentStatus.pendingValidation);
  });
}
