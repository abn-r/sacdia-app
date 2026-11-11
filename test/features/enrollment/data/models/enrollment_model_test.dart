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

  Map<String, dynamic> base(Map<String, dynamic> extra) => {
        'club_enrollment_id': '46bebcb7-3f0a-49c7-930a-a25efc9bde89',
        'club_section_id': 12,
        'year': 2026,
        'created_by': 'user-1',
        'meeting_days': 'Sábado',
        ...extra,
      };

  test('parses the review decision of a rejected enrollment', () {
    final enrollment = EnrollmentModel.fromJson(base({
      'status': 'rejected',
      'decision_reason': '  Falta el acta de la reunión  ',
      'reviewed_at': '2026-11-10T15:30:00.000Z',
    }));

    expect(enrollment.status, EnrollmentStatus.rejected);
    expect(enrollment.decisionReason, 'Falta el acta de la reunión');
    expect(enrollment.reviewedAt, DateTime.utc(2026, 11, 10, 15, 30));
  });

  test('leaves the review fields empty when the backend clears them', () {
    final enrollment = EnrollmentModel.fromJson(base({
      'status': 'pending_validation',
      'decision_reason': null,
      'reviewed_at': null,
    }));

    expect(enrollment.decisionReason, isNull);
    expect(enrollment.reviewedAt, isNull);
  });

  test('treats a blank decision_reason as no reason', () {
    final enrollment = EnrollmentModel.fromJson(base({
      'status': 'rejected',
      'decision_reason': '   ',
    }));

    expect(enrollment.decisionReason, isNull);
  });

  test('maps closed and never takes an unknown status for approved', () {
    expect(
      EnrollmentModel.fromJson(base({'status': 'closed'})).status,
      EnrollmentStatus.closed,
    );
    expect(
      EnrollmentModel.fromJson(base({'status': 'archived'})).status,
      EnrollmentStatus.inactive,
    );
    expect(
      EnrollmentModel.fromJson(base({'status': 'ACTIVE'})).status,
      EnrollmentStatus.active,
    );
  });

  test('parses fee_amount sent as a Decimal string or a number', () {
    expect(
        EnrollmentModel.fromJson(base({'fee_amount': '25.5'})).feeAmount, 25.5);
    expect(EnrollmentModel.fromJson(base({'fee_amount': 30})).feeAmount, 30);
    expect(EnrollmentModel.fromJson(base({'fee_amount': 'n/a'})).feeAmount,
        isNull);
  });

  test('parses submitted_at and tolerates its absence', () {
    final sent = EnrollmentModel.fromJson(base({
      'status': 'pending_validation',
      'submitted_at': '2026-11-09T12:00:00.000Z',
    }));
    final legacy = EnrollmentModel.fromJson(base({'status': 'active'}));

    expect(sent.submittedAt, DateTime.utc(2026, 11, 9, 12));
    expect(legacy.submittedAt, isNull);
  });
}
