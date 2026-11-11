import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/presentation/utils/join_request_groups.dart';

JoinRequest _request(String id, {JoinRequestConsent? consent}) => JoinRequest(
      assignmentId: id,
      userId: 'u-$id',
      name: 'Ana',
      status: JoinRequestStatus.pending,
      consent: consent,
    );

void main() {
  test('an own-account request is ready to approve', () {
    final groups = groupJoinRequests([_request('a')]);

    expect(groups.ready.map((r) => r.assignmentId), ['a']);
    expect(groups.review, isEmpty);
    expect(groups.waiting, isEmpty);
  });

  test('a minor with a verified consent is ready to approve', () {
    final groups = groupJoinRequests([
      _request(
        'a',
        consent: const JoinRequestConsent(
          status: JoinRequestConsentStatus.verified,
          evidenceUploaded: true,
        ),
      ),
    ]);

    expect(groups.ready, hasLength(1));
  });

  test('a pending minor with the form uploaded goes to review', () {
    final groups = groupJoinRequests([
      _request(
        'a',
        consent: const JoinRequestConsent(
          status: JoinRequestConsentStatus.pending,
          evidenceUploaded: true,
        ),
      ),
    ]);

    expect(groups.review, hasLength(1));
    expect(groups.ready, isEmpty);
    expect(groups.waiting, isEmpty);
  });

  test('a pending minor without the form is waiting for the guardian', () {
    final groups = groupJoinRequests([
      _request(
        'a',
        consent: const JoinRequestConsent(
          status: JoinRequestConsentStatus.pending,
        ),
      ),
    ]);

    expect(groups.waiting, hasLength(1));
    expect(groups.ready, isEmpty);
    expect(groups.review, isEmpty);
  });

  test('keeps the incoming order inside each group', () {
    final groups = groupJoinRequests([
      _request('a'),
      _request(
        'b',
        consent: const JoinRequestConsent(
          status: JoinRequestConsentStatus.pending,
        ),
      ),
      _request('c'),
    ]);

    expect(groups.ready.map((r) => r.assignmentId), ['a', 'c']);
    expect(groups.waiting.map((r) => r.assignmentId), ['b']);
  });
}
