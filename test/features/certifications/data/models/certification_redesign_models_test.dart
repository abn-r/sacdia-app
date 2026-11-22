import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certifications/data/models/certification_model.dart';
import 'package:sacdia_app/features/certifications/data/models/certification_progress_model.dart';
import 'package:sacdia_app/features/certifications/data/models/certification_requirement_model.dart';
import 'package:sacdia_app/features/certifications/data/models/user_certification_model.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement_component.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_status.dart';

void main() {
  group('UserCertificationModel', () {
    const base = {
      'enrollment_id': 1,
      'certification_id': 7,
      'certification_name': 'Instructor',
      'enrollment_date': '2026-02-01T00:00:00.000Z',
    };

    test('reads status, certified_at and summary', () {
      final model = UserCertificationModel.fromJson({
        ...base,
        'completion_status': true,
        'status': 'READY_FOR_CLOSEOUT',
        'certified_at': '2026-03-15T00:00:00.000Z',
        'summary': {
          'total': 19,
          'approved': 6,
          'submitted': 2,
          'changes_requested': 1,
          'not_started_or_draft': 10,
        },
      });

      expect(model.status, CertificationEnrollmentStatus.readyForCloseout);
      expect(model.status.isCloseoutOpen, isTrue);
      expect(model.certifiedAt, DateTime.utc(2026, 3, 15));
      expect(model.summary!.total, 19);
      expect(model.summary!.changesRequested, 1);
      // completion_status stays a boolean-tolerant string.
      expect(model.completionStatus, 'certified');
    });

    test('an old server without status falls back to completion_status', () {
      final inProgress = UserCertificationModel.fromJson({
        ...base,
        'completion_status': false,
      });
      final done = UserCertificationModel.fromJson({
        ...base,
        'completion_status': true,
      });

      expect(inProgress.status, CertificationEnrollmentStatus.inProgress);
      expect(inProgress.summary, isNull);
      expect(done.status, CertificationEnrollmentStatus.certified);
    });

    test('a withdrawn enrollment does not count as enrolled', () {
      final model = UserCertificationModel.fromJson({
        ...base,
        'status': 'WITHDRAWN',
      });

      expect(model.toEntity().isEnrolled, isFalse);
    });
  });

  group('CertificationProgressModel', () {
    test('reads the root status and the per-section status', () {
      final model = CertificationProgressModel.fromJson({
        'enrollment_id': 1,
        'certification_id': 7,
        'certification_name': 'Instructor',
        'enrollment_date': '2026-02-01T00:00:00.000Z',
        'completion_status': false,
        'status': 'IN_PROGRESS',
        'summary': {'total': 3, 'approved': 1},
        'modules': [
          {
            'module_id': 1,
            'module_name': 'Fundamentos',
            'sections': [
              {
                'section_id': 11,
                'section_name': 'A',
                'status': 'APPROVED',
                'reviewed_at': '2026-03-01T00:00:00.000Z',
              },
              {
                'section_id': 12,
                'section_name': 'B',
                'status': 'CHANGES_REQUESTED',
                'last_review_comment': 'Corrige',
                'required': false,
              },
              {'section_id': 13, 'section_name': 'C', 'status': 'DRAFT'},
              {'section_id': 14, 'section_name': 'D', 'status': 'NOT_STARTED'},
            ],
          },
        ],
      }).toEntity();

      expect(model.status, CertificationEnrollmentStatus.inProgress);
      expect(model.summary!.approved, 1);
      final sections = model.modules.single.sections;
      expect(sections.map((s) => s.status), [
        CertificationRequirementStatus.approved,
        CertificationRequirementStatus.changesRequested,
        CertificationRequirementStatus.draft,
        CertificationRequirementStatus.draft,
      ]);
      expect(sections[0].completed, isTrue);
      expect(sections[1].lastReviewComment, 'Corrige');
      expect(sections[1].required, isFalse);
      // A saved draft is told apart from a never started requirement.
      expect(sections[2].hasDraft, isTrue);
      expect(sections[3].hasDraft, isFalse);
      expect(model.modules.single.completedSections, 1);
    });

    test('tolerates the legacy payload with only `completed`', () {
      final entity = CertificationProgressModel.fromJson({
        'enrollment_id': 1,
        'certification_id': 7,
        'enrollment_date': '2026-02-01T00:00:00.000Z',
        'modules': [
          {
            'module_id': 1,
            'module_name': 'M',
            'sections': [
              {'section_id': 1, 'section_name': 'A', 'completed': true},
              {'section_id': 2, 'section_name': 'B', 'completed': false},
            ],
          },
        ],
      }).toEntity();

      final sections = entity.modules.single.sections;
      expect(sections[0].status, CertificationRequirementStatus.approved);
      expect(sections[1].status, CertificationRequirementStatus.draft);
      expect(entity.summary, isNull);
    });
  });

  group('CertificationRequirementModel components', () {
    test('reads instructions, configuration and uploaded evidences', () {
      final entity = CertificationRequirementModel.fromJson({
        'section_id': 22,
        'module_id': 2,
        'name': 'Plan',
        'required': true,
        'status': 'DRAFT',
        'components': [
          {
            'component_id': 2,
            'component_type': 'FILE_EVIDENCE',
            'label': 'Plan',
            'required': true,
            'instructions': 'Adjunta tu plan firmado',
            'configuration': {'max_files': 5},
            'evidences': [
              {
                'evidence_id': 31,
                'original_filename': 'plan.jpg',
                'mime_type': 'image/jpeg',
                'size_bytes': 2048,
                'confirmed_at': '2026-03-01T10:00:00.000Z',
                'url': 'https://r2.test/signed',
                'expires_in': 900,
              },
            ],
          },
        ],
      }).toEntity();

      final component = entity.components.single;
      expect(component.instructions, 'Adjunta tu plan firmado');
      expect(component.maxFiles, 5);
      expect(component.evidences.single.evidenceId, 31);
      expect(component.evidences.single.isImage, isTrue);
      expect(component.evidences.single.url, 'https://r2.test/signed');
      expect(component.isComplete, isTrue);
    });

    test('missing fields fall back to safe defaults', () {
      final component = CertificationRequirementModel.fromJson({
        'section_id': 22,
        'module_id': 2,
        'name': 'Plan',
        'status': 'DRAFT',
        'components': [
          {
            'component_id': 2,
            'component_type': 'FILE_EVIDENCE',
            'label': 'Plan',
            'required': true,
          },
        ],
      }).toEntity().components.single;

      expect(component.instructions, isNull);
      expect(component.configuration, isEmpty);
      expect(component.evidences, isEmpty);
      expect(component.maxFiles, kCertificationDefaultMaxFiles);
      expect(component.isComplete, isFalse);
    });
  });

  test('CertificationModel reads an optional requirements total', () {
    final withTotal = CertificationModel.fromJson({
      'certification_id': 7,
      'name': 'Instructor',
      'modules_count': 8,
      'requirements_count': 19,
    });
    final without = CertificationModel.fromJson({
      'certification_id': 7,
      'name': 'Instructor',
      'modules_count': 8,
    });

    expect(withTotal.requirementsCount, 19);
    expect(without.requirementsCount, isNull);
  });
}
