import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/service_credentials/data/models/service_credential_model.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential_review.dart';

void main() {
  group('serviceCredentialFromJson', () {
    test('parses a full credential', () {
      final c = serviceCredentialFromJson({
        'credential_id': 'c1',
        'type': 'COUNSELOR_TRAINING',
        'completed_at': '2026-03-14',
        'status': 'REJECTED',
        'upload_status': 'CONFIRMED',
        'decision_reason': 'Documento ilegible',
        'reviewed_at': '2026-04-02T10:00:00.000Z',
        'expires_at': null,
        'file_name': 'c.pdf',
        'created_at': '2026-04-01T10:00:00.000Z',
      });
      expect(c.id, 'c1');
      expect(c.completedAt, DateTime.parse('2026-03-14'));
      expect(c.status, ServiceCredentialStatus.rejected);
      expect(c.uploadStatus, ServiceCredentialUploadStatus.confirmed);
      expect(c.decisionReason, 'Documento ilegible');
      expect(c.expiresAt, isNull);
      expect(c.isRejected, isTrue);
      expect(c.canWithdraw, isTrue);
    });

    test('tolerates nulls, missing fields and unknown enums', () {
      final c = serviceCredentialFromJson({
        'credential_id': 7,
        'status': 'SOMETHING_NEW',
        'upload_status': 42,
        'completed_at': 'not-a-date',
        'file_name': '  ',
      });
      expect(c.id, '7');
      expect(c.status, ServiceCredentialStatus.unknown);
      expect(c.uploadStatus, ServiceCredentialUploadStatus.unknown);
      expect(c.completedAt, isNull);
      expect(c.fileName, isNull);
      // Unknown status fails closed: it is treated as pending, never approved.
      expect(c.isPending, isTrue);
      expect(c.isApproved, isFalse);
    });

    test('an approved credential cannot be withdrawn', () {
      final c = serviceCredentialFromJson(
          {'credential_id': 'c', 'status': 'APPROVED'});
      expect(c.canWithdraw, isFalse);
    });
  });

  test('serviceCredentialListFromData skips malformed rows', () {
    final list = serviceCredentialListFromData({
      'items': [
        {'credential_id': 'a'},
        'junk',
        null,
        {'credential_id': 'b'},
      ],
    });
    expect(list.map((c) => c.id), ['a', 'b']);
    expect(serviceCredentialListFromData(null), isEmpty);
    expect(serviceCredentialListFromData({'items': 'x'}), isEmpty);
  });

  test('ServiceCredentialTicket reads the presigned upload', () {
    final t = ServiceCredentialTicket.fromJson({
      'credential': {'credential_id': 'c1'},
      'upload': {
        'url': 'https://r2.example/put?sig=1',
        'method': 'put',
        'headers': {
          'Content-Type': 'application/pdf',
          'x-amz': 1,
          'skip': null
        },
        'expires_in': 300,
      },
    });
    expect(t.credential.id, 'c1');
    expect(t.uploadUrl, 'https://r2.example/put?sig=1');
    expect(t.uploadMethod, 'PUT');
    expect(t.uploadHeaders, {'Content-Type': 'application/pdf', 'x-amz': '1'});
    expect(t.expiresIn, 300);
  });

  group('review models', () {
    test('reviewPageFromBody reads items, paging and counts', () {
      final page = reviewPageFromBody({
        'status': 'success',
        'data': [
          {
            'credential_id': 'c1',
            'user': {'user_id': 'u1', 'name': 'Laura', 'photo_url': null},
            'club_name': 'Pionero',
            'status': 'PENDING_REVIEW',
            'reviewer_role': 'coordinator',
          },
        ],
        'meta': {
          'page': 2,
          'limit': 20,
          'total': 21,
          'counts': {'pending': 5, 'approved': 4, 'rejected': 3},
        },
      });
      expect(page.items.single.person.name, 'Laura');
      expect(page.items.single.clubName, 'Pionero');
      expect(page.items.single.reviewerRole, 'coordinator');
      expect(page.page, 2);
      expect(page.total, 21);
      expect(page.counts.pending, 5);
      expect(page.counts.of(ReviewStatusFilter.rejected), 3);
    });

    test('reviewPageFromBody accepts data.items and an empty meta', () {
      final page = reviewPageFromBody({
        'data': {
          'items': [
            {'credential_id': 'c1', 'user': null},
          ],
        },
      });
      expect(page.items.single.person.name, '');
      expect(page.total, 1);
      expect(page.counts.pending, 0);
    });

    test('reviewDetailFromData reads the signed file', () {
      final d = reviewDetailFromData({
        'credential_id': 'c1',
        'user': {'user_id': 'u1', 'name': 'Laura'},
        'file_url': 'https://f/x.png',
        'mime_type': 'image/png',
        'decision_reason': 'ok',
        'expires_at': '2027-01-01',
      });
      expect(d.hasFile, isTrue);
      expect(d.isImage, isTrue);
      expect(d.isPdf, isFalse);
      expect(d.expiresAt, DateTime.parse('2027-01-01'));
      expect(reviewDetailFromData({'credential_id': 'c'}).hasFile, isFalse);
    });
  });

  test('formatApiDate writes the calendar date with padding', () {
    expect(formatApiDate(DateTime(2026, 3, 4)), '2026-03-04');
    expect(formatApiDate(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
  });
}
