import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/supervision/data/models/supervision_enrollment_model.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_enrollment.dart';

Map<String, Object?> _full() => {
      'enrollment_id': 42,
      'status': 'pending_validation',
      'ecclesiastical_year': {'id': 1, 'name': '2026'},
      'club': {'id': 7, 'name': 'Club Orion'},
      'section': {
        'id': 3,
        'club_type_id': 2,
        'club_type_name': 'Conquistadores'
      },
      'local_field': {'id': 5, 'name': 'Campo Norte'},
      'address': 'Calle 1',
      'latitude': 1.5,
      'longitude': 2.5,
      'meeting_days': 'Sabado',
      'meeting_schedule': {'a': 1},
      'souls_target': 12,
      'fee': true,
      'fee_amount': 10,
      'board': {
        'director': {'user_id': 'u1', 'name': 'Dir'},
        'deputies': [
          {'user_id': 'u2', 'name': 'Dep'},
          {'name': 'no id'},
        ],
        'secretary': {'user_id': 'u3', 'name': 'Sec'},
        'treasurer': null,
        'secretary_treasurer': {'user_id': 'u4', 'name': 'ST'},
      },
      'submitted_by': {'user_id': 'u9', 'name': 'Sub'},
      'created_at': '2026-01-01T10:00:00Z',
      'submitted_at': '2026-01-02T10:00:00Z',
      'modified_at': '2026-01-03T10:00:00Z',
      'reviewed_by': {'user_id': 'r1', 'name': 'Rev'},
      'reviewer_role': 'union_supervisor',
      'reviewed_at': '2026-01-04T10:00:00Z',
      'decision_reason': 'Incomplete',
    };

void main() {
  test('parses a full item', () {
    final e = SupervisionEnrollmentModel.tryParse(_full())!;
    expect(e.id, '42');
    expect(e.status, SupervisionEnrollmentStatus.pendingValidation);
    expect(e.yearName, '2026');
    expect(e.clubName, 'Club Orion');
    expect(e.clubTypeName, 'Conquistadores');
    expect(e.localFieldName, 'Campo Norte');
    expect(e.address, 'Calle 1');
    expect(e.meetingDays, 'Sabado');
    expect(e.soulsTarget, 12);
    expect(e.hasFee, isTrue);
    expect(e.feeAmount, 10.0);
    expect(e.board.director!.name, 'Dir');
    expect(e.board.deputies, hasLength(1));
    expect(e.board.treasurer, isNull);
    expect(e.board.secretaryTreasurer!.userId, 'u4');
    expect(e.submittedBy!.userId, 'u9');
    expect(e.submittedAt, DateTime.parse('2026-01-02T10:00:00Z').toLocal());
    expect(e.reviewerRole, 'union_supervisor');
    expect(e.reviewedAt, isNotNull);
    expect(e.decisionReason, 'Incomplete');
  });

  test('missing optional fields become null and defaults', () {
    final e = SupervisionEnrollmentModel.tryParse({
      'enrollment_id': 'abc',
      'status': 'active',
    })!;
    expect(e.status, SupervisionEnrollmentStatus.active);
    expect(e.clubName, '');
    expect(e.address, isNull);
    expect(e.feeAmount, isNull);
    expect(e.hasFee, isFalse);
    expect(e.board.deputies, isEmpty);
    expect(e.submittedAt, isNull);
  });

  test('malformed fields never throw', () {
    final e = SupervisionEnrollmentModel.tryParse({
      'enrollment_id': 1,
      'status': 99,
      'club': 'oops',
      'board': [],
      'souls_target': 'x',
      'fee_amount': {},
      'submitted_at': 'not a date',
      'submitted_by': 'no',
    })!;
    expect(e.status, SupervisionEnrollmentStatus.unknown);
    expect(e.clubName, '');
    expect(e.soulsTarget, isNull);
    expect(e.feeAmount, isNull);
    expect(e.submittedAt, isNull);
    expect(e.submittedBy, isNull);
  });

  test('item without id or non-map is dropped', () {
    expect(SupervisionEnrollmentModel.tryParse({'status': 'active'}), isNull);
    expect(SupervisionEnrollmentModel.tryParse('x'), isNull);
    expect(SupervisionEnrollmentModel.tryParse(null), isNull);
  });

  test('status parse and apiValue', () {
    expect(SupervisionEnrollmentStatus.parse('rejected'),
        SupervisionEnrollmentStatus.rejected);
    expect(SupervisionEnrollmentStatus.parse(null),
        SupervisionEnrollmentStatus.unknown);
    expect(SupervisionEnrollmentStatus.pendingValidation.apiValue,
        'pending_validation');
    expect(SupervisionEnrollmentStatus.active.apiValue, 'active');
  });

  test('parsePage reads meta and counts, skips bad items', () {
    final page = SupervisionEnrollmentModel.parsePage({
      'items': [
        _full(),
        'junk',
        {'status': 'x'}
      ],
      'meta': {
        'page': 2,
        'limit': 20,
        'total': 31,
        'counts': {'pending': 5, 'approved': 20, 'rejected': 6},
      },
    });
    expect(page.items, hasLength(1));
    expect(page.page, 2);
    expect(page.total, 31);
    expect(page.counts.approved, 20);
  });

  test('parsePage tolerates garbage', () {
    final page = SupervisionEnrollmentModel.parsePage(null);
    expect(page.items, isEmpty);
    expect(page.counts.pending, 0);
    expect(page.page, 1);
  });
}
