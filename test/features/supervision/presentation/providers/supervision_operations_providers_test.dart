import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_operations.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_operations_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_operations_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';

import '../../../../support/riverpod_test_support.dart';

const _dashboard = SupervisionOperationsDashboard(
  scope: SupervisionOperationsScope(
    level: SupervisionTerritoryLevel.union,
    id: 4,
    name: 'Union',
    path: [],
  ),
  period: SupervisionOperationsPeriod(
    yearId: 1,
    yearStart: null,
    yearEnd: null,
    reportYear: null,
    reportMonth: null,
  ),
  computedAt: null,
  summary: SupervisionOperationsMetrics.empty,
  children: [],
);

class _FakeRepo implements SupervisionOperationsRepository {
  _FakeRepo(this.result);
  final Either<Failure, SupervisionOperationsDashboard> result;
  final queries = <SupervisionOperationsQuery>[];

  @override
  Future<Either<Failure, SupervisionOperationsDashboard>> getDashboard(
    SupervisionOperationsQuery query, {
    RequestCancelToken? cancelToken,
  }) async {
    queries.add(query);
    return result;
  }
}

void main() {
  test('returns the dashboard for the query', () async {
    final repo = _FakeRepo(const Right(_dashboard));
    final c = createTestContainer(overrides: [
      supervisionOperationsRepositoryProvider.overrideWithValue(repo),
    ]);
    const q = SupervisionOperationsQuery(unionId: 4);
    expect(await c.read(supervisionOperationsProvider(q).future), _dashboard);
    expect(repo.queries.single, q);
  });

  test('403 failure becomes a forbidden SupervisionLoadException', () async {
    final c = createTestContainer(overrides: [
      supervisionOperationsRepositoryProvider.overrideWithValue(
          _FakeRepo(const Left(AuthFailure(message: 'nope', code: 403)))),
    ]);
    Object? error;
    try {
      await c.read(
          supervisionOperationsProvider(const SupervisionOperationsQuery())
              .future);
    } catch (e) {
      error = e;
    }
    expect(error, isA<SupervisionLoadException>());
    expect((error as SupervisionLoadException).isForbidden, isTrue);
    expect(isForbiddenFailure(error), isTrue);
  });

  test('other failures are not forbidden', () async {
    final c = createTestContainer(overrides: [
      supervisionOperationsRepositoryProvider.overrideWithValue(
          _FakeRepo(const Left(ServerFailure(message: 'boom', code: 500)))),
    ]);
    Object? error;
    try {
      await c.read(
          supervisionOperationsProvider(const SupervisionOperationsQuery())
              .future);
    } catch (e) {
      error = e;
    }
    expect(error, isA<SupervisionLoadException>());
    expect((error as SupervisionLoadException).isForbidden, isFalse);
  });
}
