import 'package:flutter_test/flutter_test.dart';

import 'package:sacdia_app/features/evidence_folder/data/models/evidence_section_model.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_section.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/union_evaluation_decision.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _baseJson({
  String status = 'PENDING',
  String sectionId = 'sec-001',
}) =>
    {
      'section_id': sectionId,
      'name': 'Adoración',
      'description': 'Evidencias de adoración semanal.',
      'max_points': 20,
      'percentage': 10.0,
      'max_files': 5,
      'status': status,
      'evidences': <dynamic>[],
    };

Map<String, dynamic> _submittedJson() => {
      ..._baseJson(status: 'SUBMITTED'),
      'submission': {
        'submitted_by': 'Juan Pérez',
        'submitted_at': '2026-03-10T14:30:00.000Z',
      },
    };

Map<String, dynamic> _preapprovedLfJson() => {
      ..._baseJson(status: 'PREAPPROVED_LF'),
      'submission': {
        'submitted_by': 'Juan Pérez',
        'submitted_at': '2026-03-10T14:30:00.000Z',
      },
      'lf_approver': 'María García',
      'lf_approved_at': '2026-03-12T09:00:00.000Z',
    };

/// LF-only fixture: union_approver is absent — union has not acted yet.
Map<String, dynamic> _preapprovedLfOnlyJson() => {
      ..._baseJson(status: 'PREAPPROVED_LF'),
      'lf_approver': 'María García',
      'lf_approved_at': '2026-03-12T09:00:00.000Z',
      // union_approver intentionally omitted
    };

Map<String, dynamic> _validatedJson() => {
      ..._baseJson(status: 'VALIDATED'),
      'submission': {
        'submitted_by': 'Juan Pérez',
        'submitted_at': '2026-03-10T14:30:00.000Z',
      },
      'lf_approver': 'María García',
      'lf_approved_at': '2026-03-12T09:00:00.000Z',
      'union_approver': 'Carlos López',
      'union_approved_at': '2026-03-15T11:00:00.000Z',
      'union_decision': 'APPROVED',
      'evaluation': {
        'earned_points': 18,
        'notes': 'Buenas evidencias presentadas.',
      },
    };

Map<String, dynamic> _rejectedJson() => {
      ..._baseJson(status: 'REJECTED'),
      'submission': {
        'submitted_by': 'Juan Pérez',
        'submitted_at': '2026-03-10T14:30:00.000Z',
      },
      'lf_approver': 'María García',
      'lf_approved_at': '2026-03-11T10:00:00.000Z',
    };

// ── Status deserialization tests ──────────────────────────────────────────────

void main() {
  group('EvidenceSectionModel.fromJson — status mapping', () {
    test('PENDING maps to EvidenceSectionStatus.pending', () {
      final model = EvidenceSectionModel.fromJson(_baseJson(status: 'PENDING'));
      expect(model.status, EvidenceSectionStatus.pending);
    });

    test('SUBMITTED maps to EvidenceSectionStatus.submitted', () {
      final model = EvidenceSectionModel.fromJson(_submittedJson());
      expect(model.status, EvidenceSectionStatus.submitted);
    });

    test('PREAPPROVED_LF maps to EvidenceSectionStatus.preapprovedLf', () {
      final model = EvidenceSectionModel.fromJson(_preapprovedLfJson());
      expect(model.status, EvidenceSectionStatus.preapprovedLf);
    });

    test('VALIDATED maps to EvidenceSectionStatus.validated', () {
      final model = EvidenceSectionModel.fromJson(_validatedJson());
      expect(model.status, EvidenceSectionStatus.validated);
    });

    test('REJECTED maps to EvidenceSectionStatus.rejected', () {
      final model = EvidenceSectionModel.fromJson(_rejectedJson());
      expect(model.status, EvidenceSectionStatus.rejected);
    });

    test('unknown status falls back to pending', () {
      final model = EvidenceSectionModel.fromJson(
        _baseJson(status: 'LEGACY_VALUE'),
      );
      expect(model.status, EvidenceSectionStatus.pending);
    });

    test('null status falls back to pending', () {
      final json = _baseJson()..remove('status');
      final model = EvidenceSectionModel.fromJson(json);
      expect(model.status, EvidenceSectionStatus.pending);
    });
  });

  // ── Dual-actor field tests ─────────────────────────────────────────────────

  group('EvidenceSectionModel.fromJson — dual-actor fields', () {
    test('lf_approver and lf_approved_at are parsed correctly', () {
      final model = EvidenceSectionModel.fromJson(_preapprovedLfJson());
      expect(model.lfApproverName, 'María García');
      expect(model.lfApprovedAt, isNotNull);
      expect(
        model.lfApprovedAt,
        DateTime.parse('2026-03-12T09:00:00.000Z'),
      );
    });

    test('union_approver is null when absent (LF-only case)', () {
      final model = EvidenceSectionModel.fromJson(_preapprovedLfOnlyJson());
      expect(model.status, EvidenceSectionStatus.preapprovedLf);
      expect(model.lfApproverName, 'María García');
      expect(model.unionApproverName, isNull);
      expect(model.unionApprovedAt, isNull);
      expect(model.unionDecision, isNull);
    });

    test('union_approver and union_decision are parsed when present', () {
      final model = EvidenceSectionModel.fromJson(_validatedJson());
      expect(model.unionApproverName, 'Carlos López');
      expect(model.unionApprovedAt, isNotNull);
      expect(model.unionDecision, UnionEvaluationDecision.approved);
    });

    test('both actors present in validated fixture', () {
      final model = EvidenceSectionModel.fromJson(_validatedJson());
      expect(model.lfApproverName, 'María García');
      expect(model.unionApproverName, 'Carlos López');
    });
  });

  // ── EvidenceSectionStatus.toJson round-trip ───────────────────────────────

  group('EvidenceSectionStatusX.toJson — serialization', () {
    test('pending serializes to PENDING', () {
      expect(EvidenceSectionStatus.pending.toJson(), 'PENDING');
    });

    test('submitted serializes to SUBMITTED', () {
      expect(EvidenceSectionStatus.submitted.toJson(), 'SUBMITTED');
    });

    test('preapprovedLf serializes to PREAPPROVED_LF', () {
      expect(EvidenceSectionStatus.preapprovedLf.toJson(), 'PREAPPROVED_LF');
    });

    test('validated serializes to VALIDATED', () {
      expect(EvidenceSectionStatus.validated.toJson(), 'VALIDATED');
    });

    test('rejected serializes to REJECTED', () {
      expect(EvidenceSectionStatus.rejected.toJson(), 'REJECTED');
    });
  });

  // ── Submission traceability ────────────────────────────────────────────────

  group('EvidenceSectionModel.fromJson — submission traceability', () {
    test('submittedByName and submittedAt parsed from submission block', () {
      final model = EvidenceSectionModel.fromJson(_submittedJson());
      expect(model.submittedByName, 'Juan Pérez');
      expect(model.submittedAt, isNotNull);
    });

    test('no submission_status field in fixture causes no error', () {
      // Verifies the model ignores any absent submission_status key.
      final json = _submittedJson();
      expect(json.containsKey('submission_status'), isFalse);
      expect(
        () => EvidenceSectionModel.fromJson(json),
        returnsNormally,
      );
    });
  });

  // ── canSubmit / canUpload helpers ─────────────────────────────────────────

  group('EvidenceSection computed helpers', () {
    test('canSubmit is false when pending and no files', () {
      final model = EvidenceSectionModel.fromJson(_baseJson());
      expect(model.canSubmit, isFalse);
    });

    test('canUpload is true for pending', () {
      final model = EvidenceSectionModel.fromJson(_baseJson());
      expect(model.canUpload, isTrue);
    });

    test('canUpload is false for submitted', () {
      final model = EvidenceSectionModel.fromJson(_submittedJson());
      expect(model.canUpload, isFalse);
    });

    test('canUpload is true for rejected', () {
      final model = EvidenceSectionModel.fromJson(_rejectedJson());
      expect(model.canUpload, isTrue);
    });

    test('canUpload is false for preapprovedLf', () {
      final model = EvidenceSectionModel.fromJson(_preapprovedLfJson());
      expect(model.canUpload, isFalse);
    });

    test('canUpload is false for validated', () {
      final model = EvidenceSectionModel.fromJson(_validatedJson());
      expect(model.canUpload, isFalse);
    });
  });

  // ── preapprovedLf happy-path ───────────────────────────────────────────────

  group('EvidenceSection — preapprovedLf happy-path', () {
    test('preapprovedLf entity has correct status and LF actor', () {
      final model = EvidenceSectionModel.fromJson(_preapprovedLfJson());
      final entity = model.toEntity();

      expect(entity.status, EvidenceSectionStatus.preapprovedLf);
      expect(entity.lfApproverName, 'María García');
      expect(entity.unionApproverName, isNull);
      expect(entity.canUpload, isFalse);
      expect(entity.canSubmit, isFalse);
    });
  });
}
