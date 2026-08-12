import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement_component.dart';

void main() {
  CertificationRequirement buildRequirement({
    required CertificationRequirementStatus status,
    List<CertificationRequirementComponent> components = const [],
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? lastReviewComment,
  }) {
    return CertificationRequirement(
      sectionId: 1,
      moduleId: 1,
      name: 'Requisito de prueba',
      required: true,
      status: status,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt,
      lastReviewComment: lastReviewComment,
      components: components,
    );
  }

  group('CertificationRequirementStatus wire mapping', () {
    test('round-trips known statuses', () {
      const cases = {
        'DRAFT': CertificationRequirementStatus.draft,
        'SUBMITTED': CertificationRequirementStatus.submitted,
        'CHANGES_REQUESTED': CertificationRequirementStatus.changesRequested,
        'APPROVED': CertificationRequirementStatus.approved,
      };
      for (final entry in cases.entries) {
        expect(certificationRequirementStatusFromWire(entry.key), entry.value);
        expect(entry.value.wireValue, entry.key);
      }
    });

    test('unknown/null status falls back to draft', () {
      expect(
        certificationRequirementStatusFromWire('WHATEVER'),
        CertificationRequirementStatus.draft,
      );
      expect(
        certificationRequirementStatusFromWire(null),
        CertificationRequirementStatus.draft,
      );
    });
  });

  group('CertificationRequirement.canEdit', () {
    test('is editable in draft and changes_requested', () {
      expect(
        buildRequirement(status: CertificationRequirementStatus.draft).canEdit,
        isTrue,
      );
      expect(
        buildRequirement(
          status: CertificationRequirementStatus.changesRequested,
        ).canEdit,
        isTrue,
      );
    });

    test('is locked once submitted or approved', () {
      expect(
        buildRequirement(status: CertificationRequirementStatus.submitted)
            .canEdit,
        isFalse,
      );
      expect(
        buildRequirement(status: CertificationRequirementStatus.approved)
            .canEdit,
        isFalse,
      );
    });
  });

  group('CertificationRequirement.requiredComponentsComplete', () {
    test('true when there are no required components', () {
      final requirement = buildRequirement(
        status: CertificationRequirementStatus.draft,
        components: const [
          CertificationRequirementComponent(
            componentId: 1,
            type: CertificationComponentType.textResponse,
            label: 'Opcional',
            required: false,
          ),
        ],
      );
      expect(requirement.requiredComponentsComplete, isTrue);
    });

    test('false when a required component is incomplete', () {
      final requirement = buildRequirement(
        status: CertificationRequirementStatus.draft,
        components: const [
          CertificationRequirementComponent(
            componentId: 1,
            type: CertificationComponentType.textResponse,
            label: 'Obligatorio',
            required: true,
          ),
        ],
      );
      expect(requirement.requiredComponentsComplete, isFalse);
    });

    test('true when every required component is complete', () {
      final requirement = buildRequirement(
        status: CertificationRequirementStatus.draft,
        components: const [
          CertificationRequirementComponent(
            componentId: 1,
            type: CertificationComponentType.attestation,
            label: 'Obligatorio',
            required: true,
            response: CertificationComponentResponse(
              attestationConfirmed: true,
            ),
          ),
          CertificationRequirementComponent(
            componentId: 2,
            type: CertificationComponentType.autoValidation,
            label: 'Automático',
            required: true,
          ),
        ],
      );
      expect(requirement.requiredComponentsComplete, isTrue);
    });
  });

  group('CertificationRequirement.reviewHistory', () {
    test('is empty when there is no submission yet', () {
      final requirement = buildRequirement(
        status: CertificationRequirementStatus.draft,
      );
      expect(requirement.reviewHistory, isEmpty);
    });

    test('surfaces a single SUBMITTED event when awaiting review', () {
      final submittedAt = DateTime(2026, 1, 10);
      final requirement = buildRequirement(
        status: CertificationRequirementStatus.submitted,
        submittedAt: submittedAt,
      );
      expect(requirement.reviewHistory, hasLength(1));
      expect(
          requirement.reviewHistory.single.eventType, 'REQUIREMENT_SUBMITTED');
      expect(requirement.reviewHistory.single.occurredAt, submittedAt);
    });

    test('surfaces CHANGES_REQUESTED with the reviewer comment', () {
      final reviewedAt = DateTime(2026, 1, 12);
      final requirement = buildRequirement(
        status: CertificationRequirementStatus.changesRequested,
        submittedAt: DateTime(2026, 1, 10),
        reviewedAt: reviewedAt,
        lastReviewComment: 'Falta evidencia',
      );
      final event = requirement.reviewHistory.single;
      expect(event.eventType, 'REQUIREMENT_CHANGES_REQUESTED');
      expect(event.comment, 'Falta evidencia');
      expect(event.occurredAt, reviewedAt);
    });

    test('surfaces APPROVED once reviewed positively', () {
      final reviewedAt = DateTime(2026, 1, 15);
      final requirement = buildRequirement(
        status: CertificationRequirementStatus.approved,
        submittedAt: DateTime(2026, 1, 10),
        reviewedAt: reviewedAt,
      );
      expect(
        requirement.reviewHistory.single.eventType,
        'REQUIREMENT_APPROVED',
      );
    });
  });
}
