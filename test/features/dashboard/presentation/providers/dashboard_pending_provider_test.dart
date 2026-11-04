import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_pending.dart';
import 'package:sacdia_app/features/dashboard/domain/repositories/dashboard_pending_repository.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_pending_provider.dart';
import '../../../../support/riverpod_test_support.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

class _CountingRepository implements DashboardPendingRepository {
  int calls = 0;

  @override
  Future<Either<Failure, DashboardPending>> getPending({
    RequestCancelToken? cancelToken,
  }) async {
    calls++;
    return Right(
      DashboardPending(total: calls, urgent: 0, items: const []),
    );
  }
}

UserEntity _user({String? activeAssignmentId}) => UserEntity(
      id: 'user-1',
      email: 'user@example.com',
      authorization:
          AuthorizationSnapshot(activeAssignmentId: activeAssignmentId),
    );

void main() {
  test('does not request anything while the active assignment is unknown',
      () async {
    final repository = _CountingRepository();
    final container = createTestContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(_user())),
        dashboardPendingRepositoryProvider.overrideWithValue(repository),
      ],
    );

    expect(await container.read(dashboardPendingProvider.future), isNull);
    expect(repository.calls, 0);
  });

  test('invalidating it (pull-to-refresh) fetches again', () async {
    final repository = _CountingRepository();
    final container = createTestContainer(
      overrides: [
        authNotifierProvider.overrideWith(
          () => _FakeAuthNotifier(_user(activeAssignmentId: 'a-1')),
        ),
        dashboardPendingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final subscription = container.listen(
      dashboardPendingProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);

    expect((await container.read(dashboardPendingProvider.future))?.total, 1);

    container.invalidate(dashboardPendingProvider);
    expect((await container.read(dashboardPendingProvider.future))?.total, 2);
    expect(repository.calls, 2);
  });
}
