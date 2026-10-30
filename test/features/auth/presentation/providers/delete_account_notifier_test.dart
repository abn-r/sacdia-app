import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/notifications/push_notification_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/delete_account_reauth.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import 'auth_notifier_test_support.dart';

class _DeleteRepo extends FakeAuthRepository {
  _DeleteRepo({
    this.deleteResult = const Right(null),
    this.providersResult = const Right([]),
  });

  final Either<Failure, void> deleteResult;
  final Either<Failure, List<SocialProvider>> providersResult;
  DeleteAccountReauth? received;

  @override
  Future<Either<Failure, void>> deleteAccount(
      DeleteAccountReauth reauth) async {
    received = reauth;
    return deleteResult;
  }

  @override
  Future<Either<Failure, List<SocialProvider>>> getConnectedProviders() async =>
      providersResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const socialReauth = SocialReauth(
    SocialCredential(
      provider: SocialProvider.apple,
      idToken: 'apple-token',
      nonce: 'n-1',
    ),
  );

  Future<ProviderContainer> build(_DeleteRepo repo) async {
    final container = await buildAuthContainer(repo: repo);
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    return container;
  }

  test('deleteAccount forwards the social reauth and returns null', () async {
    final repo = _DeleteRepo();
    final container = await build(repo);

    final error = await container
        .read(authNotifierProvider.notifier)
        .deleteAccount(socialReauth);

    expect(error, isNull);
    expect(repo.received, same(socialReauth));
    expect(container.read(authNotifierProvider).valueOrNull, isNull);
  });

  test('deleteAccount returns the failure message', () async {
    final repo = _DeleteRepo(
      deleteResult: const Left(AuthFailure(message: 'Contraseña incorrecta')),
    );
    final container = await build(repo);

    final error = await container
        .read(authNotifierProvider.notifier)
        .deleteAccount(const PasswordReauth('bad'));

    expect(error, 'Contraseña incorrecta');
  });

  test('connectedProviders returns the repository list', () async {
    final container = await build(
      _DeleteRepo(providersResult: const Right([SocialProvider.apple])),
    );

    expect(
      await container.read(authNotifierProvider.notifier).connectedProviders(),
      [SocialProvider.apple],
    );
  });

  test('connectedProviders is empty when the lookup fails', () async {
    final container = await build(
      _DeleteRepo(providersResult: const Left(ServerFailure(message: 'boom'))),
    );

    expect(
      await container.read(authNotifierProvider.notifier).connectedProviders(),
      isEmpty,
    );
  });

  FakePushNotificationService pushOf(ProviderContainer container) =>
      container.read(pushNotificationServiceProvider)
          as FakePushNotificationService;

  test('a failed deletion keeps push registration untouched', () async {
    final repo = _DeleteRepo(
      deleteResult: const Left(AuthFailure(message: 'Contraseña incorrecta')),
    );
    final container = await build(repo);

    await container
        .read(authNotifierProvider.notifier)
        .deleteAccount(const PasswordReauth('bad'));

    final push = pushOf(container);
    expect(push.clearLocalCalls, 0);
    expect(push.unregisterCalls, 0);
    expect(push.disposeCalls, 0);
  });

  test(
    'a successful deletion clears push locally without calling the backend',
    () async {
      final container = await build(_DeleteRepo());

      final error = await container
          .read(authNotifierProvider.notifier)
          .deleteAccount(socialReauth);

      expect(error, isNull);
      final push = pushOf(container);
      expect(push.clearLocalCalls, 1);
      // unregisterToken() hace un DELETE al backend; sin sesión daría 401 y
      // expiraría la sesión a mitad de la UI.
      expect(push.unregisterCalls, 0);
    },
  );

  test('deleteAccountWithResult exposes the business code of the failure',
      () async {
    final repo = _DeleteRepo(
      deleteResult: const Left(
        AuthFailure(
          message: 'Confirma qué pasará con los menores',
          code: 409,
          errorCode: 'AUTH_DELETE_DEPENDENTS_ACK_REQUIRED',
        ),
      ),
    );
    final container = await build(repo);

    final result = await container
        .read(authNotifierProvider.notifier)
        .deleteAccountWithResult(const PasswordReauth('pw'));

    expect(result.isSuccess, isFalse);
    expect(result.needsDependentsAck, isTrue);
    expect(result.errorMessage, 'Confirma qué pasará con los menores');
  });

  test('the acknowledged reauth reaches the repository untouched', () async {
    final repo = _DeleteRepo();
    final container = await build(repo);

    final result = await container
        .read(authNotifierProvider.notifier)
        .deleteAccountWithResult(const PasswordReauth('pw').acknowledged());

    expect(result.isSuccess, isTrue);
    expect(repo.received!.acknowledgeDependents, isTrue);
  });
}
