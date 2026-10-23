import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_notifier_test_support.dart';

const _noEmailUser = UserEntity(
  id: 'dep-1',
  name: 'Ana',
  actingFor: ActingForInfo(
    actorUserId: 'guardian-1',
    dependentUserId: 'dep-1',
  ),
  family: FamilySummary(isGuardian: true, dependentsCount: 1),
);

class _OnlineRepository extends FakeAuthRepository {
  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      const Right(_noEmailUser);
}

class _OfflineRepository extends FakeAuthRepository {
  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      const Left(NetworkFailure(message: 'offline'));
}

void main() {
  test('a user without email loads and does not cache an email', () async {
    final storage = FakeSecureStorage();
    // A stale email from a previous session must not survive.
    await storage.write('cached_user_email', 'old@example.com');

    final container = await buildAuthContainer(
      repo: _OnlineRepository(),
      storage: storage,
    );
    addTearDown(container.dispose);

    final user = await container.read(authNotifierProvider.future);

    expect(user?.id, 'dep-1');
    expect(user?.email, isNull);
    expect(await storage.read('cached_user_email'), isNull);
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('mark* helpers keep acting/family and a null email', () async {
    final container = await buildAuthContainer(repo: _OnlineRepository());
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    final notifier = container.read(authNotifierProvider.notifier);

    notifier.markPostRegisterComplete();
    var current = container.read(authNotifierProvider).valueOrNull;
    expect(current?.email, isNull);
    expect(current?.actingFor?.dependentUserId, 'dep-1');
    expect(current?.family?.dependentsCount, 1);

    notifier.markLegalAccepted();
    current = container.read(authNotifierProvider).valueOrNull;
    expect(current?.actingFor, isNotNull);
    expect(current?.family, isNotNull);

    notifier.markPostRegisterIncomplete();
    current = container.read(authNotifierProvider).valueOrNull;
    expect(current?.actingFor, isNotNull);
    expect(current?.family, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('offline restore works when no email was cached', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FakeSecureStorage();
    await storage.write('cached_user_id', 'user-1');
    await storage.write('cached_user_name', 'Elena');

    final container = await buildAuthContainer(
      repo: _OfflineRepository(),
      storage: storage,
      prefs: prefs,
    );
    addTearDown(container.dispose);

    final user = await container.read(authNotifierProvider.future);

    expect(user?.id, 'user-1');
    expect(user?.email, isNull);
    expect(user?.actingFor, isNull);
  }, timeout: const Timeout(Duration(seconds: 15)));
}
