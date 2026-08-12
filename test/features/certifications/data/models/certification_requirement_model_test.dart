import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certifications/data/models/certification_requirement_model.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement_component.dart';

void main() {
  group('CertificationRequirementModel.fromJson', () {
    test('maps a full RequirementView payload to the domain entity', () {
      final json = {
        'section_id': 10,
        'module_id': 3,
        'name': 'Liderazgo de club',
        'required': true,
        'status': 'CHANGES_REQUESTED',
        'submitted_at': '2026-01-10T12:00:00.000Z',
        'reviewed_at': '2026-01-12T08:30:00.000Z',
        'last_review_comment': 'Falta la firma del director',
        'components': [
          {
            'component_id': 1,
            'component_type': 'TEXT_RESPONSE',
            'label': 'Describe tu experiencia',
            'required': true,
            'response': {'text_value': 'Llevo 3 años como líder'},
          },
          {
            'component_id': 2,
            'component_type': 'FILE_EVIDENCE',
            'label': 'Sube tu evidencia',
            'required': false,
          },
        ],
      };

      final entity = CertificationRequirementModel.fromJson(json).toEntity();

      expect(entity.sectionId, 10);
      expect(entity.moduleId, 3);
      expect(entity.name, 'Liderazgo de club');
      expect(entity.status, CertificationRequirementStatus.changesRequested);
      expect(entity.lastReviewComment, 'Falta la firma del director');
      expect(entity.components, hasLength(2));

      final textComponent = entity.components[0];
      expect(textComponent.type, CertificationComponentType.textResponse);
      expect(textComponent.response?.textValue, 'Llevo 3 años como líder');

      final fileComponent = entity.components[1];
      expect(fileComponent.type, CertificationComponentType.fileEvidence);
      expect(fileComponent.required, isFalse);
      expect(fileComponent.response, isNull);
    });

    test('applies safe defaults for missing optional fields', () {
      final json = {
        'section_id': 5,
        'module_id': 1,
      };

      final entity = CertificationRequirementModel.fromJson(json).toEntity();

      expect(entity.name, '');
      expect(entity.required, isFalse);
      expect(entity.status, CertificationRequirementStatus.draft);
      expect(entity.submittedAt, isNull);
      expect(entity.reviewedAt, isNull);
      expect(entity.lastReviewComment, isNull);
      expect(entity.components, isEmpty);
    });
  });

  group('CertificationRequirementSubmitResultModel.fromJson', () {
    test('maps requirement + camelCase progress_summary sub-object', () {
      final json = {
        'requirement': {
          'section_id': 10,
          'module_id': 3,
          'name': 'Liderazgo de club',
          'required': true,
          'status': 'SUBMITTED',
        },
        'progress_summary': {
          'requiredTotal': 5,
          'requiredApproved': 2,
          'optionalTotal': 1,
          'optionalApproved': 0,
          'percentComplete': 40,
          'allRequiredApproved': false,
        },
      };

      final entity =
          CertificationRequirementSubmitResultModel.fromJson(json).toEntity();

      expect(
          entity.requirement.status, CertificationRequirementStatus.submitted);
      expect(entity.progressSummary.requiredTotal, 5);
      expect(entity.progressSummary.requiredApproved, 2);
      expect(entity.progressSummary.percentComplete, 40);
      expect(entity.progressSummary.allRequiredApproved, isFalse);
    });
  });
}
