import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import 'auth_notifier_test_support.dart';

class _SocialRepo extends FakeAuthRepository {
  _SocialRepo(this.googleResult);

  final Either<Failure, UserEntity> googleResult;

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async => googleResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const user = UserEntity(
    id: 'user-1',
    email: 'ana@example.com',
    name: 'Ana',
    postRegisterComplete: false,
  );

  test(
    'success caches the user and returns SocialSignInResult.success',
    () async {
      final container = await buildAuthContainer(
        repo: _SocialRepo(const Right(user)),
      );
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      final result = await container
          .read(authNotifierProvider.notifier)
          .signInWithGoogle();

      expect(result, SocialSignInResult.success);
      expect(container.read(authNotifierProvider).value?.id, 'user-1');
    },
  );

  test('cancel leaves the state without error and returns cancelled', () async {
    final container = await buildAuthContainer(
      repo: _SocialRepo(Left(SocialSignInCancelledFailure())),
    );
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);

    final result =
        await container.read(authNotifierProvider.notifier).signInWithGoogle();

    expect(result, SocialSignInResult.cancelled);
    expect(container.read(authNotifierProvider), isNot(isA<AsyncError>()));
    expect(container.read(authNotifierProvider).value, isNull);
  });

  test('failure puts the message in the error state and returns failed',
      () async {
    final container = await buildAuthContainer(
      repo: _SocialRepo(
        const Left(
          AuthFailure(message: 'No pudimos verificar tu cuenta de Google'),
        ),
      ),
    );
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);

    final result =
        await container.read(authNotifierProvider.notifier).signInWithGoogle();

    expect(result, SocialSignInResult.failed);
    expect(
      container.read(authNotifierProvider).error,
      'No pudimos verificar tu cuenta de Google',
    );
  });
}
