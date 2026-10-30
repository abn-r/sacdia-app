import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_notifier_test_support.dart';

const _pendingUser = UserEntity(
  id: 'user-1',
  email: 'user@example.com',
  name: 'Elena',
  legalAcceptancePending: true,
);

class _OnlineRepository extends FakeAuthRepository {
  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      const Right(_pendingUser);
}

class _OfflineRepository extends FakeAuthRepository {
  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      const Left(NetworkFailure(message: 'offline'));
}

void main() {
  test('markLegalAccepted clears the flag and keeps the rest of the user',
      () async {
    final container = await buildAuthContainer(repo: _OnlineRepository());
    final states = <AsyncValue<UserEntity?>>[];
    container.listen(authNotifierProvider, (_, next) => states.add(next));

    final loaded = await container.read(authNotifierProvider.future);
    expect(loaded?.legalAcceptancePending, isTrue);

    container.read(authNotifierProvider.notifier).markLegalAccepted();

    final updated = container.read(authNotifierProvider).valueOrNull;
    expect(updated?.legalAcceptancePending, isFalse);
    expect(updated?.id, 'user-1');
    expect(updated?.name, 'Elena');
    // El estado cambia de verdad (el flag participa en la igualdad), así que
    // el router se notifica.
    expect(states.last.valueOrNull?.legalAcceptancePending, isFalse);
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('markPostRegisterComplete/Incomplete carry the pending flag', () async {
    final container = await buildAuthContainer(repo: _OnlineRepository());
    await container.read(authNotifierProvider.future);
    final notifier = container.read(authNotifierProvider.notifier);

    notifier.markPostRegisterComplete();
    final complete = container.read(authNotifierProvider).valueOrNull;
    expect(complete?.postRegisterComplete, isTrue);
    expect(complete?.legalAcceptancePending, isTrue);

    notifier.markPostRegisterIncomplete();
    final incomplete = container.read(authNotifierProvider).valueOrNull;
    expect(incomplete?.postRegisterComplete, isFalse);
    expect(incomplete?.legalAcceptancePending, isTrue);
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('offline restore never reports pending (server is the truth)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FakeSecureStorage();
    await storage.write('cached_user_id', 'user-1');
    await storage.write('cached_user_email', 'user@example.com');
    await storage.write('cached_user_name', 'Elena');

    final container = await buildAuthContainer(
      repo: _OfflineRepository(),
      storage: storage,
      prefs: prefs,
    );

    final user = await container.read(authNotifierProvider.future);

    expect(user?.id, 'user-1');
    expect(user?.legalAcceptancePending, isFalse);
  }, timeout: const Timeout(Duration(seconds: 15)));
}
