import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/role_candidates_providers.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential_review.dart';
import 'package:sacdia_app/features/service_credentials/presentation/providers/service_credentials_providers.dart';

import '../../../support/riverpod_test_support.dart';
import '../../members/members_test_support.dart' show FakeMembersRepository;
import '../service_credentials_test_support.dart';

void main() {
  late FakeServiceCredentialsRepository repo;

  setUp(() => repo = FakeServiceCredentialsRepository());

  ProviderContainer container0() => createTestContainer(overrides: [
        serviceCredentialsRepositoryProvider.overrideWithValue(repo),
      ]);

  group('myServiceCredentialsProvider', () {
    test('sorts newest first and keeps rows without a date last', () async {
      repo.mine = Right([
        credential(id: 'old', createdAt: DateTime(2026, 1, 1)),
        const ServiceCredential(id: 'none'),
        credential(id: 'new', createdAt: DateTime(2026, 5, 1)),
      ]);
      final container = container0();
      final list = await container.read(myServiceCredentialsProvider.future);
      expect(list.map((c) => c.id), ['new', 'old', 'none']);
    });

    test('hides abandoned uploads (PENDING_UPLOAD)', () async {
      repo.mine = const Right([
        ServiceCredential(
          id: 'abandoned',
          uploadStatus: ServiceCredentialUploadStatus.pendingUpload,
        ),
        ServiceCredential(
          id: 'ok',
          uploadStatus: ServiceCredentialUploadStatus.confirmed,
        ),
      ]);
      final list = await container0().read(myServiceCredentialsProvider.future);
      expect(list.map((c) => c.id), ['ok']);
    });

    test('fails with the original Failure', () async {
      repo.mine = const Left(serverFailure);
      final container = container0();
      await expectLater(
        container.read(myServiceCredentialsProvider.future),
        throwsA(same(serverFailure)),
      );
    });
  });

  group('submit', () {
    test('returns null, invalidates the list and passes the data', () async {
      final container = container0();
      await container.read(myServiceCredentialsProvider.future);
      repo.calls.clear();

      final draft = ServiceCredentialDraft(
        completedAt: DateTime(2026, 3, 1),
      );
      // Nobody listens to the notifier: keepAliveDuring must carry it.
      final failure = await container
          .read(serviceCredentialSubmitProvider.notifier)
          .submit(draft: draft, file: localFile());

      expect(failure, isNull);
      expect(repo.lastDraft, draft);
      expect(repo.lastFile?.name, 'constancia.pdf');
      // The list is rebuilt on the next read.
      await container.read(myServiceCredentialsProvider.future);
      expect(repo.calls, contains('getMine'));
    });

    test('returns the Failure and leaves the list alone', () async {
      repo.submitResult = const Left(serverFailure);
      final container = container0();
      final failure =
          await container.read(serviceCredentialSubmitProvider.notifier).submit(
                draft: ServiceCredentialDraft(
                  completedAt: DateTime(2026, 3, 1),
                ),
                file: localFile(),
              );
      expect(
          (failure as Failure).errorCode, 'SERVICE_CREDENTIAL_PENDING_EXISTS');
      expect(repo.calls, ['submit']);
    });
  });

  test('withdraw returns null on success and the Failure otherwise', () async {
    final container = container0();
    final notifier = container.read(serviceCredentialWithdrawProvider.notifier);
    expect(await notifier.withdraw('c1'), isNull);
    repo.withdrawResult = const Left(serverFailure);
    expect(await notifier.withdraw('c2'), same(serverFailure));
    expect(repo.calls, ['withdraw:c1', 'withdraw:c2']);
    expect(container.read(serviceCredentialWithdrawProvider), isEmpty);
  });

  group('review queue', () {
    test('first page carries the counts and loadMore appends without dupes',
        () async {
      repo.queue = (status, search, page) => Right(
            page == 1
                ? reviewPage(
                    [reviewItem(id: 'a'), reviewItem(id: 'b')],
                    total: 3,
                    limit: 2,
                  )
                : reviewPage(
                    [reviewItem(id: 'b'), reviewItem(id: 'c')],
                    total: 3,
                    page: 2,
                    limit: 2,
                  ),
          );
      final container = container0();
      const query = ReviewQueueQuery();
      final first = await container.read(reviewQueueProvider(query).future);
      expect(first.items.map((i) => i.id), ['a', 'b']);
      expect(first.counts.pending, 2);
      expect(first.hasMore, isTrue);

      await container.read(reviewQueueProvider(query).notifier).loadMore();
      final state = container.read(reviewQueueProvider(query)).requireValue;
      expect(state.items.map((i) => i.id), ['a', 'b', 'c']);
      expect(state.hasMore, isFalse);
      expect(repo.queueRequests.last.page, 2);
    });

    test('a failed next page keeps the list and flags loadMoreFailed',
        () async {
      var calls = 0;
      repo.queue = (_, __, ___) {
        calls++;
        return calls == 1
            ? Right(reviewPage([reviewItem(id: 'a')], total: 5, limit: 1))
            : const Left(serverFailure);
      };
      final container = container0();
      const query = ReviewQueueQuery();
      await container.read(reviewQueueProvider(query).future);
      await container.read(reviewQueueProvider(query).notifier).loadMore();
      final state = container.read(reviewQueueProvider(query)).requireValue;
      expect(state.items, hasLength(1));
      expect(state.loadMoreFailed, isTrue);
      expect(state.isLoadingMore, isFalse);
    });

    test('the pending count reads meta.counts.pending with one row', () async {
      repo.queue = (_, __, ___) => Right(reviewPage(
            const [],
            counts: const ReviewCounts(pending: 7),
          ));
      final container = container0();
      expect(await container.read(reviewPendingCountProvider.future), 7);
      expect(repo.queueRequests.single.status, ReviewStatusFilter.pending);
    });

    test('the queue fails with the original Failure', () async {
      repo.queue = (_, __, ___) => const Left(serverFailure);
      final container = container0();
      await expectLater(
        container.read(reviewQueueProvider(const ReviewQueueQuery()).future),
        throwsA(same(serverFailure)),
      );
    });
  });

  group('review actions', () {
    test('approve passes the expiry and invalidates queue, count and detail',
        () async {
      final container = container0();
      await container.read(reviewPendingCountProvider.future);
      await container.read(reviewDetailProvider('c1').future);
      repo.calls.clear();

      final failure = await container
          .read(serviceCredentialReviewActionsProvider.notifier)
          .approve('c1', expiresAt: DateTime(2027, 1, 9));
      expect(failure, isNull);
      expect(repo.lastExpiresAt, DateTime(2027, 1, 9));

      await container.read(reviewPendingCountProvider.future);
      await container.read(reviewDetailProvider('c1').future);
      expect(repo.calls,
          containsAll(['approve:c1', 'queue:PENDING_REVIEW', 'detail:c1']));
    });

    test('approving refreshes the role-candidates lists', () async {
      final members = FakeMembersRepository();
      final container = createTestContainer(overrides: [
        serviceCredentialsRepositoryProvider.overrideWithValue(repo),
        membersRepositoryProvider.overrideWithValue(members),
      ]);
      const query = RoleCandidatesQuery(clubId: 1, sectionId: 163);
      // The «Agregar directivo» sheet is open: someone listens to the list.
      container.listen(roleCandidatesProvider(query), (_, __) {});
      await container.read(roleCandidatesProvider(query).future);
      expect(members.roleCandidateCalls, hasLength(1));

      final failure = await container
          .read(serviceCredentialReviewActionsProvider.notifier)
          .approve('c1');
      expect(failure, isNull);
      await container.read(roleCandidatesProvider(query).future);
      expect(members.roleCandidateCalls, hasLength(2));
    });

    test('reject passes the reason', () async {
      final container = container0();
      final failure = await container
          .read(serviceCredentialReviewActionsProvider.notifier)
          .reject('c1', reason: 'Documento ilegible');
      expect(failure, isNull);
      expect(repo.lastReason, 'Documento ilegible');
    });

    test('a 409 returns the Failure and still reloads the stale queue',
        () async {
      repo.approveResult = const Left(ServerFailure(
        message: 'x',
        code: 409,
        errorCode: 'SERVICE_CREDENTIAL_NOT_PENDING',
      ));
      final container = container0();
      await container.read(reviewPendingCountProvider.future);
      repo.calls.clear();
      final failure = await container
          .read(serviceCredentialReviewActionsProvider.notifier)
          .approve('c1');
      expect((failure as Failure).errorCode, 'SERVICE_CREDENTIAL_NOT_PENDING');
      await container.read(reviewPendingCountProvider.future);
      expect(repo.calls, contains('queue:PENDING_REVIEW'));
    });
  });
}
