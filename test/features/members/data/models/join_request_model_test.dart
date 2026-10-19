import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/data/models/join_request_model.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';

import '../../members_test_support.dart';

Map<String, dynamic> _item({
  Object? consent,
  String? email = 'luis@example.com',
}) =>
    {
      'assignment_id': 'req-1',
      'club_section_id': 12,
      'user_id': 'user-1',
      'status': 'pending',
      'created_at': '2026-10-12T10:00:00.000Z',
      'users': {
        'user_id': 'user-1',
        'name': 'Luis',
        'paternal_last_name': 'Soto',
        'email': email,
      },
      'consent': consent,
    };

void main() {
  group('consent block', () {
    test('adults have no consent block', () {
      final request = JoinRequestModel.fromJson(_item());
      expect(request.consent, isNull);
      expect(request.isMinorWithConsent, isFalse);
      expect(request.consentPending, isFalse);
    });

    test('a pending minor blocks direct approval', () {
      final request = JoinRequestModel.fromJson(_item(
        consent: consentJson(evidence: true),
        email: null,
      ));

      expect(request.isMinorWithConsent, isTrue);
      expect(request.consent?.status, JoinRequestConsentStatus.pending);
      expect(request.consent?.guardianshipId, 'gs-1');
      expect(request.consent?.evidenceUploaded, isTrue);
      expect(request.consentPending, isTrue);
      expect(request.email, isNull, reason: 'dependents have no email');
      expect(request.consent?.guardians.single.displayName, 'María Pérez');
      expect(request.consent?.guardians.single.relationshipTypeName, 'Madre');
      expect(request.consent?.guardians.single.isPrimary, isTrue);
    });

    test('a verified minor can be approved directly', () {
      final request = JoinRequestModel.fromJson(_item(
        consent: consentJson(status: 'verified'),
      ));
      expect(request.consent?.isVerified, isTrue);
      expect(request.consentPending, isFalse);
    });

    test('an unknown status is read as pending (the safe side)', () {
      expect(
        JoinRequestConsentStatus.parse('weird'),
        JoinRequestConsentStatus.pending,
      );
      expect(
        JoinRequestModel.fromJson(_item(consent: {'status': null}))
            .consentPending,
        isTrue,
      );
    });

    test('a missing guardians list does not crash', () {
      final request = JoinRequestModel.fromJson(_item(
        consent: {'status': 'pending', 'guardianship_id': null},
      ));
      expect(request.consent?.guardians, isEmpty);
      expect(request.consent?.guardianshipId, isNull);
    });

    test('the section prefix is kept so consent calls reuse the approve path',
        () {
      final request = JoinRequestModel.fromJson(_item());
      expect(request.assignmentId, '12/membership-requests/req-1');
    });
  });
}
