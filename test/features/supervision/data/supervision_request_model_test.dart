import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/supervision/data/models/supervision_request_model.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_request.dart';

void main() {
  test('status parse and apiValue', () {
    expect(SupervisionRequestStatus.parse('pending'),
        SupervisionRequestStatus.pending);
    expect(SupervisionRequestStatus.parse('APPROVED'),
        SupervisionRequestStatus.approved);
    expect(
        SupervisionRequestStatus.parse('x'), SupervisionRequestStatus.unknown);
    expect(
        SupervisionRequestStatus.parse(null), SupervisionRequestStatus.unknown);
    expect(SupervisionRequestStatus.rejected.apiValue, 'rejected');
    expect(SupervisionRequestStatus.unknown.apiValue, isNull);
  });

  test('transfer: full payload', () {
    final m = SupervisionRequestModel.fromTransferJson({
      'transfer_request_id': 'T1',
      'user_id': 'U1',
      'status': 'approved',
      'reason': 'moved',
      'review_comment': 'ok',
      'reviewed_at': '2026-01-02T10:00:00Z',
      'created_at': '2026-01-01T10:00:00Z',
      'user': {'user_id': 'U1', 'name': 'Ana', 'paternal_last_name': 'Lopez'},
      'reviewer': {'user_id': 'R', 'name': 'Rey', 'paternal_last_name': 'Diaz'},
      'from_section': {
        'club_section_id': 1,
        'club_types': {'name': 'Conquistadores'},
        'clubs': {'name': 'Club A'},
      },
      'to_section': {
        'club_section_id': 2,
        'club_types': {'name': 'Aventureros'},
        'clubs': {'name': 'Club B'},
      },
    });
    expect(m.kind, SupervisionRequestKind.transfer);
    expect(m.id, 'T1');
    expect(m.status, SupervisionRequestStatus.approved);
    expect(m.personName, 'Ana Lopez');
    expect(m.personId, 'U1');
    expect(m.reviewerName, 'Rey Diaz');
    expect(m.reviewComment, 'ok');
    expect(m.reason, 'moved');
    expect(m.fromClubName, 'Club A');
    expect(m.fromSectionLabel, 'Conquistadores');
    expect(m.toClubName, 'Club B');
    expect(m.toSectionLabel, 'Aventureros');
    expect(m.createdAt, isNotNull);
    expect(m.reviewedAt, isNotNull);
  });

  test('transfer: nulls, missing clubs and malformed input never throw', () {
    final m = SupervisionRequestModel.fromTransferJson({
      'transfer_request_id': 7,
      'status': 'pending',
      'created_at': 'not a date',
      'user': {'name': 'Ana'},
      'reviewer': null,
      'from_section': {
        'club_types': {'name': 'Conquistadores'}
      },
      'to_section': 'garbage',
    });
    expect(m.id, '7');
    expect(m.personName, 'Ana');
    expect(m.createdAt, isNull);
    expect(m.reviewerName, isNull);
    expect(m.fromClubName, isNull);
    expect(m.fromSectionLabel, 'Conquistadores');
    expect(m.toSectionLabel, isNull);

    final empty = SupervisionRequestModel.fromTransferJson('nope');
    expect(empty.id, '');
    expect(empty.status, SupervisionRequestStatus.unknown);
    expect(empty.personName, '');
  });

  test('assignment: full payload', () {
    final m = SupervisionRequestModel.fromAssignmentJson({
      'request_id': 'A1',
      'user_id': 'U2',
      'status': 'rejected',
      'comment': 'no',
      'reviewed_at': '2026-02-01T00:00:00Z',
      'created_at': '2026-01-30T00:00:00Z',
      'user': {'user_id': 'U2', 'name': 'Luis', 'paternal_last_name': 'Paz'},
      'requester': {'name': 'Dir', 'paternal_last_name': 'Ector'},
      'approver': {'name': 'Sup', 'paternal_last_name': 'Ervisor'},
      'role': {'role_id': 3, 'role_name': 'Tesorero'},
      'club_section': {
        'club_types': {'name': 'Guías Mayores'},
        'clubs': {'name': 'Club C'},
      },
    });
    expect(m.kind, SupervisionRequestKind.assignment);
    expect(m.id, 'A1');
    expect(m.status, SupervisionRequestStatus.rejected);
    expect(m.personName, 'Luis Paz');
    expect(m.roleName, 'Tesorero');
    expect(m.clubName, 'Club C');
    expect(m.sectionLabel, 'Guías Mayores');
    expect(m.requestedByName, 'Dir Ector');
    expect(m.reviewerName, 'Sup Ervisor');
    expect(m.reviewComment, 'no');
  });

  test('assignment: nulls and missing clubs', () {
    final m = SupervisionRequestModel.fromAssignmentJson({
      'request_id': 'A2',
      'status': 'pending',
      'approver': null,
      'role': 5,
      'club_section': {
        'club_types': {'name': 'Aventureros'}
      },
    });
    expect(m.roleName, isNull);
    expect(m.clubName, isNull);
    expect(m.sectionLabel, 'Aventureros');
    expect(m.reviewerName, isNull);
    expect(m.requestedByName, isNull);
    expect(m.personName, '');
  });

  test('fillMissingFrom keeps known names and takes review fields', () {
    const previous = SupervisionRequest(
      kind: SupervisionRequestKind.transfer,
      id: 'T1',
      status: SupervisionRequestStatus.pending,
      personName: 'Ana',
      personId: 'U1',
      fromClubName: 'Club A',
      toClubName: 'Club B',
    );
    const updated = SupervisionRequest(
      kind: SupervisionRequestKind.transfer,
      id: 'T1',
      status: SupervisionRequestStatus.approved,
      personName: 'Ana',
      personId: 'U1',
      reviewComment: 'ok',
    );
    final merged = updated.fillMissingFrom(previous);
    expect(merged.fromClubName, 'Club A');
    expect(merged.toClubName, 'Club B');
    expect(merged.status, SupervisionRequestStatus.approved);
    expect(merged.reviewComment, 'ok');
  });
}
