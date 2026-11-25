import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_request.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_repository.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_requests_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_requests_providers.dart';

import '../../../../support/riverpod_test_support.dart';

const _listed = SupervisionRequest(
  kind: SupervisionRequestKind.transfer,
  id: 'T1',
  status: SupervisionRequestStatus.pending,
  personName: 'Ana Lopez',
  personId: 'U1',
  fromClubName: 'Club A',
  toClubName: 'Club B',
);

const _reviewed = SupervisionRequest(
  kind: SupervisionRequestKind.transfer,
  id: 'T1',
  status: SupervisionRequestStatus.approved,
  personName: 'Ana Lopez',
  personId: 'U1',
);

class _FakeRepo implements SupervisionRequestsRepository {
  _FakeRepo({this.listResult, this.reviewResult});

  Either<Failure, List<SupervisionRequest>>? listResult;
  Either<Failure, SupervisionRequest>? reviewResult;
  int listCalls = 0;
  String? lastComment = 'unset';

  @override
  Future<Either<Failure, List<SupervisionRequest>>> getRequests({
    required SupervisionRequestKind kind,
    required SupervisionRequestStatus status,
    RequestCancelToken? cancelToken,
  }) async {
    listCalls++;
    return listResult ?? const Right([]);
  }

  @override
  Future<Either<Failure, SupervisionRequest>> review({
    required SupervisionRequestKind kind,
    required String requestId,
    required bool approve,
    String? comment,
  }) async {
    lastComment = comment;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return reviewResult!;
  }
}

class _CountsRepo implements SupervisionRepository {
  int calls = 0;

  @override
  Future<Either<Failure, SupervisionPendingCounts>> getPendingCounts({
    RequestCancelToken? cancelToken,
  }) async {
    calls++;
    return const Right(SupervisionPendingCounts(territoryLevel: 'union'));
  }
}

const _query = SupervisionRequestsQuery(
  kind: SupervisionRequestKind.transfer,
  status: SupervisionRequestStatus.pending,
);

void main() {
  test('list provider returns the items', () async {
    final repo = _FakeRepo(listResult: const Right([_listed]));
    final c = createTestContainer(overrides: [
      supervisionRequestsRepositoryProvider.overrideWithValue(repo),
    ]);
    expect(await c.read(supervisionRequestsProvider(_query).future), [_listed]);
  });

  test('403 is a SupervisionLoadException classified as forbidden', () async {
    final repo = _FakeRepo(
        listResult: const Left(AuthFailure(message: 'nope', code: 403)));
    final c = createTestContainer(overrides: [
      supervisionRequestsRepositoryProvider.overrideWithValue(repo),
    ]);
    Object? error;
    try {
      await c.read(supervisionRequestsProvider(_query).future);
    } catch (e) {
      error = e;
    }
    expect(error, isA<SupervisionLoadException>());
    expect(isForbiddenFailure(error!), isTrue);
  });

  test(
      'success invalidates lists and pending counts, keeps club names, '
      'works without listeners', () async {
    final repo = _FakeRepo(
        listResult: const Right([_listed]),
        reviewResult: const Right(_reviewed));
    final counts = _CountsRepo();
    final c = createTestContainer(overrides: [
      supervisionRequestsRepositoryProvider.overrideWithValue(repo),
      supervisionRepositoryProvider.overrideWithValue(counts),
    ]);
    // Keep list and counts alive so invalidation triggers a refetch.
    final s1 = c.listen(supervisionRequestsProvider(_query), (_, __) {});
    final s2 = c.listen(supervisionPendingCountsProvider, (_, __) {});
    addTearDown(s1.close);
    addTearDown(s2.close);
    await c.read(supervisionRequestsProvider(_query).future);
    await c.read(supervisionPendingCountsProvider.future);
    expect(repo.listCalls, 1);
    expect(counts.calls, 1);

    final result = await c
        .read(supervisionRequestReviewerProvider)
        .review(_listed, approve: true, comment: '  ');
    expect(result.ok, isTrue);
    expect(repo.lastComment, isNull);
    expect(result.request!.status, SupervisionRequestStatus.approved);
    expect(result.request!.fromClubName, 'Club A');
    expect(result.request!.toClubName, 'Club B');

    await c.read(supervisionRequestsProvider(_query).future);
    await c.read(supervisionPendingCountsProvider.future);
    expect(repo.listCalls, 2);
    expect(counts.calls, 2);
  });

  test('comment is trimmed before sending', () async {
    final repo = _FakeRepo(reviewResult: const Right(_reviewed));
    final c = createTestContainer(overrides: [
      supervisionRequestsRepositoryProvider.overrideWithValue(repo),
      supervisionRepositoryProvider.overrideWithValue(_CountsRepo()),
    ]);
    await c
        .read(supervisionRequestReviewerProvider)
        .review(_listed, approve: false, comment: ' motivo ');
    expect(repo.lastComment, 'motivo');
  });

  for (final code in const [
    'REQUEST_TRANSFER_ALREADY_REVIEWED',
    'REQUEST_TRANSFER_NOT_FOUND',
  ]) {
    test('$code returns the error and invalidates the lists', () async {
      final repo = _FakeRepo(
        listResult: const Right([_listed]),
        reviewResult: Left(
            ServerFailure(message: 'server says', code: 409, errorCode: code)),
      );
      final c = createTestContainer(overrides: [
        supervisionRequestsRepositoryProvider.overrideWithValue(repo),
      ]);
      final sub = c.listen(supervisionRequestsProvider(_query), (_, __) {});
      addTearDown(sub.close);
      await c.read(supervisionRequestsProvider(_query).future);

      final result = await c
          .read(supervisionRequestReviewerProvider)
          .review(_listed, approve: true);
      expect(result.ok, isFalse);
      expect(result.errorCode, code);
      expect(result.errorMessage, 'server says');

      await c.read(supervisionRequestsProvider(_query).future);
      expect(repo.listCalls, 2);
    });
  }

  test('other errors surface code and message without invalidating', () async {
    final repo = _FakeRepo(
      listResult: const Right([_listed]),
      reviewResult: const Left(ServerFailure(
          message: 'slots full',
          code: 409,
          errorCode: 'REQUEST_ROLE_SLOT_LIMIT_REACHED')),
    );
    final c = createTestContainer(overrides: [
      supervisionRequestsRepositoryProvider.overrideWithValue(repo),
    ]);
    final sub = c.listen(supervisionRequestsProvider(_query), (_, __) {});
    addTearDown(sub.close);
    await c.read(supervisionRequestsProvider(_query).future);

    final result = await c
        .read(supervisionRequestReviewerProvider)
        .review(_listed, approve: true);
    expect(result.errorCode, 'REQUEST_ROLE_SLOT_LIMIT_REACHED');
    expect(result.errorMessage, 'slots full');
    expect(repo.listCalls, 1);
  });
}
