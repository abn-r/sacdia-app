import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_scope.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/consent_review_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

import '../../../members/members_test_support.dart';

CoordinatorSectionScope _section(int id) => CoordinatorSectionScope(
      clubSectionId: id,
      name: 'Conquistadores',
      clubTypeId: 2,
      clubTypeName: 'Conquistadores',
      clubId: 100 + id,
      clubName: 'Club $id',
    );

CoordinatorScope _scope(int count) => CoordinatorScope(
      isCoordinator: count > 0,
      clubSectionIds: [for (var i = 1; i <= count; i++) i],
      sections: [for (var i = 1; i <= count; i++) _section(i)],
    );

JoinRequest _minor(int sectionId, {String id = 'req-1', String name = 'Ana'}) =>
    JoinRequest(
      assignmentId: '$sectionId/membership-requests/$id',
      userId: 'user-$sectionId-$id',
      name: name,
      status: JoinRequestStatus.pending,
      consent: const JoinRequestConsent(
        status: JoinRequestConsentStatus.pending,
        evidenceUploaded: true,
      ),
    );

JoinRequest _adult(int sectionId) => JoinRequest(
      assignmentId: '$sectionId/membership-requests/adult',
      userId: 'adult-$sectionId',
      name: 'Luis',
      status: JoinRequestStatus.pending,
    );

const _outOfScope = Left<Failure, List<JoinRequest>>(
  AuthFailure(
    message: 'x',
    code: 403,
    errorCode: 'GUARD_CLUB_SCOPE_REQUIRED',
  ),
);

const _boom = Left<Failure, List<JoinRequest>>(
  ServerFailure(message: 'x', code: 500),
);

void main() {
  late FakeMembersRepository repo;

  setUp(() => repo = FakeMembersRepository());

  ProviderContainer container({required CoordinatorScope scope}) {
    final c = ProviderContainer(
      overrides: [
        membersRepositoryProvider.overrideWithValue(repo),
        coordinatorScopeProvider.overrideWith((ref) async => scope),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('loads only the first page of sections, never all of them', () async {
    repo.requestsBySection[2] = Right([_minor(2)]);
    final c = container(scope: _scope(12));

    final state = await c.read(consentReviewProvider.future);

    expect(repo.joinRequestSectionCalls,
        List.generate(ConsentReviewNotifier.sectionsPerPage, (i) => i + 1));
    expect(state.sections, hasLength(12));
    expect(state.checkedCount, ConsentReviewNotifier.sectionsPerPage);
    expect(state.hasMore, isTrue);
  });

  test('keeps the requests in flight bounded by the page size', () async {
    repo.joinRequestsGate = Completer<void>();
    final c = container(scope: _scope(40));

    final pending = c.read(consentReviewProvider.future);
    await pumpEventQueue();
    expect(repo.joinRequestsInFlight, ConsentReviewNotifier.sectionsPerPage);

    repo.joinRequestsGate!.complete();
    await pending;
    expect(repo.joinRequestsMaxInFlight, ConsentReviewNotifier.sectionsPerPage);
  });

  test('keeps only sections with a minor waiting for verification', () async {
    repo.requestsBySection[1] = Right([_adult(1)]);
    repo.requestsBySection[2] = Right([_minor(2), _adult(2)]);
    repo.requestsBySection[3] = const Right([]);
    final c = container(scope: _scope(3));

    final state = await c.read(consentReviewProvider.future);

    expect(state.entries.map((e) => e.section.clubSectionId), [2]);
    expect(state.entries.single.requests.map((r) => r.name), ['Ana']);
    expect(state.totalForms, 1);
    expect(state.hasMore, isFalse);
  });

  test('a verified minor is not waiting for anything', () async {
    repo.requestsBySection[1] = Right([
      JoinRequest(
        assignmentId: '1/membership-requests/v',
        userId: 'v',
        name: 'Vera',
        status: JoinRequestStatus.pending,
        consent: const JoinRequestConsent(
          status: JoinRequestConsentStatus.verified,
          evidenceUploaded: true,
        ),
      ),
    ]);
    final c = container(scope: _scope(1));

    final state = await c.read(consentReviewProvider.future);

    expect(state.entries, isEmpty);
  });

  test('loadMore asks for the next page and keeps the section order', () async {
    repo.requestsBySection[1] = Right([_minor(1)]);
    repo.requestsBySection[8] = Right([_minor(8)]);
    final c = container(scope: _scope(8));
    await c.read(consentReviewProvider.future);
    repo.joinRequestSectionCalls.clear();

    await c.read(consentReviewProvider.notifier).loadMore();

    expect(repo.joinRequestSectionCalls, [6, 7, 8]);
    final state = c.read(consentReviewProvider).requireValue;
    expect(state.entries.map((e) => e.section.clubSectionId), [1, 8]);
    expect(state.hasMore, isFalse);
    expect(state.loadingMore, isFalse);
  });

  test('loadMore with nothing left does not call the server', () async {
    final c = container(scope: _scope(2));
    await c.read(consentReviewProvider.future);
    repo.joinRequestSectionCalls.clear();

    await c.read(consentReviewProvider.notifier).loadMore();

    expect(repo.joinRequestSectionCalls, isEmpty);
  });

  test('GUARD_CLUB_SCOPE_REQUIRED drops the section and keeps the rest',
      () async {
    repo.requestsBySection[1] = _outOfScope;
    repo.requestsBySection[2] = Right([_minor(2)]);
    final c = container(scope: _scope(2));

    final state = await c.read(consentReviewProvider.future);

    expect(state.droppedSectionIds, {1});
    expect(state.failedSectionIds, isEmpty);
    expect(state.entries.map((e) => e.section.clubSectionId), [2]);
  });

  test('any other failure is kept to retry, only for those sections', () async {
    repo.requestsBySection[1] = _boom;
    repo.requestsBySection[2] = Right([_minor(2)]);
    final c = container(scope: _scope(2));
    final state = await c.read(consentReviewProvider.future);
    expect(state.failedSectionIds, {1});
    expect(state.droppedSectionIds, isEmpty);

    repo.requestsBySection[1] = Right([_minor(1)]);
    repo.joinRequestSectionCalls.clear();
    await c.read(consentReviewProvider.notifier).retryFailed();

    expect(repo.joinRequestSectionCalls, [1]);
    final after = c.read(consentReviewProvider).requireValue;
    expect(after.failedSectionIds, isEmpty);
    expect(after.entries.map((e) => e.section.clubSectionId), [1, 2]);
  });

  test('removeRequest drops the verified form and the emptied section',
      () async {
    repo.requestsBySection[1] = Right([_minor(1), _minor(1, id: 'req-2')]);
    repo.requestsBySection[2] = Right([_minor(2)]);
    final c = container(scope: _scope(2));
    await c.read(consentReviewProvider.future);
    final notifier = c.read(consentReviewProvider.notifier);

    notifier.removeRequest('1/membership-requests/req-1');
    var state = c.read(consentReviewProvider).requireValue;
    expect(state.entries.map((e) => e.section.clubSectionId), [1, 2]);
    expect(state.totalForms, 2);

    notifier.removeRequest('2/membership-requests/req-1');
    state = c.read(consentReviewProvider).requireValue;
    expect(state.entries.map((e) => e.section.clubSectionId), [1]);
  });

  test('someone who is not a coordinator asks for nothing', () async {
    final c = container(
      scope: const CoordinatorScope(isCoordinator: false),
    );

    final state = await c.read(consentReviewProvider.future);

    expect(repo.joinRequestSectionCalls, isEmpty);
    expect(state.sections, isEmpty);
    expect(state.entries, isEmpty);
    expect(state.hasMore, isFalse);
  });

  test('a scope that cannot be loaded is an error, not an empty list',
      () async {
    final c = ProviderContainer(
      overrides: [
        membersRepositoryProvider.overrideWithValue(repo),
        coordinatorScopeProvider.overrideWith(
          (ref) async => throw Exception('network'),
        ),
      ],
    );
    addTearDown(c.dispose);

    await expectLater(
      c.read(consentReviewProvider.future),
      throwsA(isA<Exception>()),
    );
    expect(repo.joinRequestSectionCalls, isEmpty);
  });
}
