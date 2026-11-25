import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/supervision/data/models/supervision_folder_model.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';

Map<String, dynamic> _section(Object id, {int order = 1, Object? status}) => {
      'section_id': id,
      'name': 'S$id',
      'order': order,
      'required': true,
      'max_points': 10,
      if (status != null) 'status': status,
    };

void main() {
  group('enums', () {
    test('folder status parse', () {
      expect(
          SupervisionFolderStatus.parse('open'), SupervisionFolderStatus.open);
      expect(SupervisionFolderStatus.parse('submitted'),
          SupervisionFolderStatus.submitted);
      expect(SupervisionFolderStatus.parse('under_evaluation'),
          SupervisionFolderStatus.underEvaluation);
      expect(SupervisionFolderStatus.parse('evaluated'),
          SupervisionFolderStatus.evaluated);
      expect(SupervisionFolderStatus.parse('closed'),
          SupervisionFolderStatus.closed);
      expect(
          SupervisionFolderStatus.parse('x'), SupervisionFolderStatus.unknown);
      expect(
          SupervisionFolderStatus.parse(null), SupervisionFolderStatus.unknown);
    });

    test('section status parse', () {
      expect(SupervisionSectionStatus.parse('PENDING'),
          SupervisionSectionStatus.pending);
      expect(SupervisionSectionStatus.parse('SUBMITTED'),
          SupervisionSectionStatus.submitted);
      expect(SupervisionSectionStatus.parse('PREAPPROVED_LF'),
          SupervisionSectionStatus.preapprovedLf);
      expect(SupervisionSectionStatus.parse('VALIDATED'),
          SupervisionSectionStatus.validated);
      expect(SupervisionSectionStatus.parse('REJECTED'),
          SupervisionSectionStatus.rejected);
      expect(SupervisionSectionStatus.parse('nope'),
          SupervisionSectionStatus.unknown);
    });

    test('queue filter api values', () {
      expect(SupervisionFolderQueueFilter.needsReview.apiValue, 'needs_review');
      expect(SupervisionFolderQueueFilter.evaluated.apiValue, 'evaluated');
      expect(SupervisionFolderQueueFilter.all.apiValue, 'all');
    });
  });

  group('queue item', () {
    test('full item', () {
      final item = SupervisionFolderModel.tryParseQueueItem({
        'annual_folder_id': 'f1',
        'display_name': 'Orion - 2026',
        'club_name': 'Orion',
        'club_section_name': 'Conquistadores',
        'club_type_name': 'Conquistadores',
        'local_field_name': 'Campo',
        'union_name': 'Union',
        'template_name': 'Plantilla',
        'year_label': '2026',
        'folder_status': 'submitted',
        'total_sections': 8,
        'total_evidences': 20,
        'submitted_sections_count': 3,
        'preapproved_sections_count': 2,
        'validated_sections_count': 1,
        'rejected_sections_count': 0,
        'pending_section_names': ['A', 'B'],
        'latest_submitted_at': '2026-05-01T10:00:00Z',
        'created_at': '2026-01-01T00:00:00Z',
      })!;
      expect(item.id, 'f1');
      expect(item.sectionName, 'Conquistadores');
      expect(item.folderStatus, SupervisionFolderStatus.submitted);
      expect(item.totalSections, 8);
      expect(item.submittedSections, 3);
      expect(item.preapprovedSections, 2);
      expect(item.validatedSections, 1);
      expect(item.pendingSectionNames, ['A', 'B']);
      expect(item.latestSubmittedAt, isNotNull);
      expect(item.createdAt!.isUtc, isFalse);
    });

    test('nulls and numeric strings become defaults', () {
      final item = SupervisionFolderModel.tryParseQueueItem({
        'annual_folder_id': 7,
        'club_name': null,
        'total_sections': '5',
        'submitted_sections_count': '2',
        'rejected_sections_count': 'x',
        'pending_section_names': [null, 'A', 3],
        'latest_submitted_at': 'garbage',
      })!;
      expect(item.id, '7');
      expect(item.clubName, '');
      expect(item.yearLabel, '');
      expect(item.totalSections, 5);
      expect(item.submittedSections, 2);
      expect(item.rejectedSections, 0);
      expect(item.pendingSectionNames, ['A', '3']);
      expect(item.latestSubmittedAt, isNull);
      expect(item.folderStatus, SupervisionFolderStatus.unknown);
    });

    test('malformed input never throws', () {
      expect(SupervisionFolderModel.tryParseQueueItem(null), isNull);
      expect(SupervisionFolderModel.tryParseQueueItem('x'), isNull);
      expect(
          SupervisionFolderModel.tryParseQueueItem({'club_name': 'a'}), isNull);
      final item = SupervisionFolderModel.tryParseQueueItem({
        'annual_folder_id': 'a',
        'pending_section_names': 'oops',
      })!;
      expect(item.pendingSectionNames, isEmpty);
    });

    test('page parses nested data and skips unusable items', () {
      final page = SupervisionFolderModel.parseQueuePage({
        'data': [
          {'annual_folder_id': 'a'},
          {'no_id': true},
          'junk',
          {'annual_folder_id': 'b'},
        ],
        'total': '40',
        'page': 2,
        'limit': 25,
      });
      expect(page.items.map((e) => e.id), ['a', 'b']);
      expect(page.total, 40);
      expect(page.page, 2);
      expect(page.limit, 25);
    });

    test('page with malformed payload is empty', () {
      final page = SupervisionFolderModel.parseQueuePage('x');
      expect(page.items, isEmpty);
      expect(page.total, 0);
      expect(page.page, 1);
    });
  });

  group('detail', () {
    Map<String, dynamic> fullFolder() => {
          'annual_folder_id': 'f1',
          'status': 'under_evaluation',
          'submitted_at': '2026-05-01T10:00:00Z',
          'closed_at': null,
          'evaluated_at': '2026-05-02T10:00:00Z',
          'total_earned_points': '30',
          'total_max_points': 80.0,
          'progress_percentage': '37.5',
          'requires_union_confirmation': true,
          'club_enrollment': {
            'club_section': {
              'name': 'Conquistadores',
              'club_type': {'name': 'Tipo'},
              'club': {
                'name': 'Orion',
                'local_field': {
                  'name': 'Campo',
                  'union': {'name': 'Union'},
                },
              },
            },
            'ecclesiastical_year': {'label': '2026'},
          },
          'template': {'name': 'Plantilla'},
          'sections': [
            _section('b', order: 2),
            _section('a', order: 1),
          ],
        };

    test('full folder', () {
      final d = SupervisionFolderModel.tryParseDetail(fullFolder())!;
      expect(d.id, 'f1');
      expect(d.status, SupervisionFolderStatus.underEvaluation);
      expect(d.clubName, 'Orion');
      expect(d.sectionName, 'Conquistadores');
      expect(d.clubTypeName, 'Tipo');
      expect(d.localFieldName, 'Campo');
      expect(d.unionName, 'Union');
      expect(d.templateName, 'Plantilla');
      expect(d.yearLabel, '2026');
      expect(d.totalEarnedPoints, 30);
      expect(d.totalMaxPoints, 80);
      expect(d.progressPercentage, 37.5);
      expect(d.requiresUnionConfirmation, isTrue);
      expect(d.submittedAt, isNotNull);
      expect(d.closedAt, isNull);
      expect(d.evaluatedAt, isNotNull);
    });

    test('sections are sorted by order, stable for ties', () {
      final json = fullFolder()
        ..['sections'] = [
          _section('c', order: 3),
          _section('x', order: 1),
          _section('b', order: 2),
          _section('y', order: 1),
        ];
      final d = SupervisionFolderModel.tryParseDetail(json)!;
      expect(d.sections.map((s) => s.id), ['x', 'y', 'b', 'c']);
    });

    test('nulls and malformed nested data fall back to defaults', () {
      final d = SupervisionFolderModel.tryParseDetail({
        'annual_folder_id': 'f',
        'club_enrollment': 'bad',
        'template': null,
        'sections': 'bad',
        'total_earned_points': null,
        'progress_percentage': 'abc',
      })!;
      expect(d.clubName, '');
      expect(d.templateName, '');
      expect(d.sections, isEmpty);
      expect(d.totalEarnedPoints, 0);
      expect(d.progressPercentage, 0);
      expect(d.requiresUnionConfirmation, isFalse);
      expect(d.status, SupervisionFolderStatus.unknown);
    });

    test('no id or non-map yields null', () {
      expect(SupervisionFolderModel.tryParseDetail(null), isNull);
      expect(
          SupervisionFolderModel.tryParseDetail(<String, dynamic>{}), isNull);
      expect(SupervisionFolderModel.tryParseDetail([1]), isNull);
    });

    test('unusable sections are skipped', () {
      final d = SupervisionFolderModel.tryParseDetail({
        'annual_folder_id': 'f',
        'sections': [
          'x',
          {'name': 'no id'},
          _section('ok'),
        ],
      })!;
      expect(d.sections.map((s) => s.id), ['ok']);
    });
  });

  group('section', () {
    test('status derivation: explicit status wins', () {
      final s = SupervisionFolderModel.tryParseSection({
        ..._section('a', status: 'VALIDATED'),
        'evaluation': {'status': 'REJECTED'},
        'submission': {'submitted_at': '2026-05-01T10:00:00Z'},
      })!;
      expect(s.status, SupervisionSectionStatus.validated);
    });

    test('status derivation: evaluation status when no section status', () {
      final s = SupervisionFolderModel.tryParseSection({
        ..._section('a'),
        'evaluation': {'status': 'PREAPPROVED_LF'},
      })!;
      expect(s.status, SupervisionSectionStatus.preapprovedLf);
    });

    test('status derivation: submission without evaluation is submitted', () {
      final s = SupervisionFolderModel.tryParseSection({
        ..._section('a'),
        'evaluation': null,
        'submission': {
          'section_submission_id': 1,
          'submitted_at': '2026-05-01T10:00:00Z',
        },
      })!;
      expect(s.status, SupervisionSectionStatus.submitted);
      expect(s.submittedAt, isNotNull);
    });

    test('status derivation: nothing yields pending', () {
      final s = SupervisionFolderModel.tryParseSection(_section('a'))!;
      expect(s.status, SupervisionSectionStatus.pending);
      expect(s.earnedPoints, isNull);
      expect(s.submittedAt, isNull);
    });

    test('status derivation: unrecognised value is unknown', () {
      final s = SupervisionFolderModel.tryParseSection(
          _section('a', status: 'WEIRD'))!;
      expect(s.status, SupervisionSectionStatus.unknown);
    });

    test('full section with evaluation and person names', () {
      final s = SupervisionFolderModel.tryParseSection({
        'section_id': 's1',
        'name': 'Nombre',
        'description': 'Desc',
        'order': '2',
        'required': true,
        'max_points': '15',
        'minimum_points': 5,
        'evidence_count': 1,
        'evidences': [
          {
            'evidence_id': 'e1',
            'file_url': 'https://x/f.pdf',
            'file_name': 'f.pdf',
            'notes': 'n',
            'reviewer_note': 'r',
            'reviewer_noted_by': {
              'name': 'Ana',
              'paternal_last_name': 'Lopez',
            },
            'reviewer_noted_at': '2026-05-03T00:00:00Z',
            'uploaded_by': 'Luis Perez',
            'created_at': '2026-05-01T00:00:00Z',
          },
        ],
        'evaluation': {
          'evaluation_id': 1,
          'status': 'PREAPPROVED_LF',
          'earned_points': '12',
          'max_points': 15,
          'notes': 'bien',
          'lf_approver': {'name': 'Pedro', 'paternal_last_name': 'Ruiz'},
          'lf_approved_at': '2026-05-02T00:00:00Z',
          'union_approver': 'Maria Gomez',
          'union_approved_at': '2026-05-04T00:00:00Z',
          'union_decision': 'APPROVED',
        },
        'submission': {
          'submitted_at': '2026-05-01T09:00:00Z',
          'submitted_by': 'x',
        },
      })!;
      expect(s.id, 's1');
      expect(s.order, 2);
      expect(s.isRequired, isTrue);
      expect(s.maxPoints, 15);
      expect(s.minimumPoints, 5);
      expect(s.status, SupervisionSectionStatus.preapprovedLf);
      expect(s.earnedPoints, 12);
      expect(s.evaluationNotes, 'bien');
      expect(s.lfApproverName, 'Pedro Ruiz');
      expect(s.lfApprovedAt, isNotNull);
      expect(s.unionApproverName, 'Maria Gomez');
      expect(s.unionDecision, 'APPROVED');
      final e = s.evidences.single;
      expect(e.id, 'e1');
      expect(e.reviewerNote, 'r');
      expect(e.reviewerNotedByName, 'Ana Lopez');
      expect(e.uploadedByName, 'Luis Perez');
      expect(e.createdAt, isNotNull);
    });

    test('person fields: string, id, object, blank', () {
      SupervisionFolderEvidence ev(Object? uploadedBy) =>
          SupervisionFolderModel.tryParseEvidence(
              {'evidence_id': 'e', 'uploaded_by': uploadedBy})!;
      expect(ev('  Ana  ').uploadedByName, 'Ana');
      expect(ev(12).uploadedByName, isNull);
      expect(ev(null).uploadedByName, isNull);
      expect(ev('   ').uploadedByName, isNull);
      expect(ev({'name': 'Ana'}).uploadedByName, 'Ana');
      expect(
        ev({
          'name': 'Ana',
          'paternal_last_name': 'L',
          'maternal_last_name': 'M'
        }).uploadedByName,
        'Ana L M',
      );
      expect(ev({'user_id': 'u'}).uploadedByName, isNull);
    });

    test('evidence defaults and malformed input', () {
      final e = SupervisionFolderModel.tryParseEvidence(
          {'evidence_id': 'e', 'reviewer_note': ''})!;
      expect(e.fileUrl, '');
      expect(e.fileName, '');
      expect(e.reviewerNote, isNull);
      expect(
          SupervisionFolderModel.tryParseEvidence({'file_name': 'x'}), isNull);
      expect(SupervisionFolderModel.tryParseEvidence(3), isNull);
    });

    test('section evidences list tolerates junk entries', () {
      final s = SupervisionFolderModel.tryParseSection({
        ..._section('a'),
        'evidences': [
          'x',
          {'evidence_id': 'e1'},
          {'nope': 1},
        ],
      })!;
      expect(s.evidences.map((e) => e.id), ['e1']);
    });
  });
}
