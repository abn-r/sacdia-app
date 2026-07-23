import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_section_registration_model.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';

Map<String, dynamic> _registrationJson({
  String status = 'registered',
  String disposition = 'open',
  Object? blockingReason,
  Object? enrollmentId = 91,
  Object? registeredAt = '2026-07-13T18:30:00.000Z',
  Object? registeredBy = const {
    'userId': 'director-1',
    'displayName': 'Directora Activa',
  },
}) =>
    {
      'camporeeId': 7,
      'clubId': 12,
      'clubName': 'Orión',
      'clubSectionId': 44,
      'sectionName': 'Conquistadores',
      'clubTypeId': 2,
      'clubTypeName': 'Conquistadores',
      'status': status,
      'disposition': disposition,
      'canEnroll': false,
      'blockingReason': blockingReason,
      'enrollmentId': enrollmentId,
      'registeredAt': registeredAt,
      'registeredBy': registeredBy,
    };

void main() {
  group('CamporeeSectionRegistrationModel.fromJson', () {
    test('parses the complete contextual registration contract', () {
      final model = CamporeeSectionRegistrationModel.fromJson(
        _registrationJson(),
      );

      expect(model.camporeeId, 7);
      expect(model.clubId, 12);
      expect(model.clubName, 'Orión');
      expect(model.clubSectionId, 44);
      expect(model.sectionName, 'Conquistadores');
      expect(model.clubTypeId, 2);
      expect(model.clubTypeName, 'Conquistadores');
      expect(model.status, CamporeeSectionRegistrationStatus.registered);
      expect(model.disposition, CamporeeSectionRegistrationDisposition.open);
      expect(model.canEnroll, isFalse);
      expect(model.enrollmentId, 91);
      expect(model.registeredAt, DateTime.utc(2026, 7, 13, 18, 30));
      expect(model.registeredBy?.userId, 'director-1');
      expect(model.registeredBy?.displayName, 'Directora Activa');
    });

    test('maps every known status and preserves unknown values safely', () {
      const cases = {
        'not_enrolled': CamporeeSectionRegistrationStatus.notEnrolled,
        'registered': CamporeeSectionRegistrationStatus.registered,
        'pending_approval': CamporeeSectionRegistrationStatus.pendingApproval,
        'approved': CamporeeSectionRegistrationStatus.approved,
        'rejected': CamporeeSectionRegistrationStatus.rejected,
        'cancelled': CamporeeSectionRegistrationStatus.cancelled,
        'future_backend_status': CamporeeSectionRegistrationStatus.unknown,
      };

      for (final entry in cases.entries) {
        final model = CamporeeSectionRegistrationModel.fromJson(
          _registrationJson(status: entry.key),
        );
        expect(model.status, entry.value, reason: entry.key);
      }
    });

    test('maps every known disposition and preserves unknown values safely',
        () {
      const cases = {
        'not_open_yet': CamporeeSectionRegistrationDisposition.notOpenYet,
        'open': CamporeeSectionRegistrationDisposition.open,
        'late_approval_required':
            CamporeeSectionRegistrationDisposition.lateApprovalRequired,
        'manually_frozen':
            CamporeeSectionRegistrationDisposition.manuallyFrozen,
        'future_backend_disposition':
            CamporeeSectionRegistrationDisposition.unknown,
      };

      for (final entry in cases.entries) {
        final model = CamporeeSectionRegistrationModel.fromJson(
          _registrationJson(disposition: entry.key),
        );
        expect(model.disposition, entry.value, reason: entry.key);
      }
    });

    test('accepts nullable enrollment metadata', () {
      final model = CamporeeSectionRegistrationModel.fromJson(
        _registrationJson(
          status: 'not_enrolled',
          blockingReason: 'not_open_yet',
          enrollmentId: null,
          registeredAt: null,
          registeredBy: null,
        ),
      );

      expect(model.blockingReason, 'not_open_yet');
      expect(model.enrollmentId, isNull);
      expect(model.registeredAt, isNull);
      expect(model.registeredBy, isNull);
    });
  });

  group('CamporeeSectionRegistration', () {
    CamporeeSectionRegistration registration(
      CamporeeSectionRegistrationStatus status,
    ) =>
        CamporeeSectionRegistration(
          camporeeId: 7,
          clubId: 12,
          clubName: 'Orión',
          clubSectionId: 44,
          sectionName: 'Conquistadores',
          clubTypeId: 2,
          clubTypeName: 'Conquistadores',
          status: status,
          disposition: CamporeeSectionRegistrationDisposition.open,
          canEnroll: false,
        );

    test('enables participants only for registered and approved statuses', () {
      for (final status in CamporeeSectionRegistrationStatus.values) {
        expect(
          registration(status).enablesParticipants,
          status == CamporeeSectionRegistrationStatus.registered ||
              status == CamporeeSectionRegistrationStatus.approved,
          reason: status.name,
        );
      }
    });
  });
}
