import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';

import '../../../../support/riverpod_test_support.dart';

class _FakeRepo implements SupervisionRepository {
  _FakeRepo(this.result);
  final Either<Failure, SupervisionPendingCounts> result;

  @override
  Future<Either<Failure, SupervisionPendingCounts>> getPendingCounts({
    RequestCancelToken? cancelToken,
  }) async =>
      result;
}

void main() {
  test('returns the entity', () async {
    const counts = SupervisionPendingCounts(
        territoryLevel: 'union', clubEnrollments: 3, transfers: 2);
    final c = createTestContainer(overrides: [
      supervisionRepositoryProvider
          .overrideWithValue(_FakeRepo(const Right(counts))),
    ]);
    expect(await c.read(supervisionPendingCountsProvider.future), counts);
  });

  test('403 failure propagates and is classified as forbidden', () async {
    final c = createTestContainer(overrides: [
      supervisionRepositoryProvider.overrideWithValue(
          _FakeRepo(const Left(AuthFailure(message: 'nope', code: 403)))),
    ]);
    Object? error;
    try {
      await c.read(supervisionPendingCountsProvider.future);
    } catch (e) {
      error = e;
    }
    expect(error, isA<SupervisionLoadException>());
    expect(isForbiddenFailure(error!), isTrue);
  });

  test('other failures are not forbidden', () async {
    final c = createTestContainer(overrides: [
      supervisionRepositoryProvider.overrideWithValue(
          _FakeRepo(const Left(ServerFailure(message: 'boom', code: 500)))),
    ]);
    Object? error;
    try {
      await c.read(supervisionPendingCountsProvider.future);
    } catch (e) {
      error = e;
    }
    expect(error, isA<SupervisionLoadException>());
    expect(isForbiddenFailure(error!), isFalse);
  });
}
