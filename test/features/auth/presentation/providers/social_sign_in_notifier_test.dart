import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import 'auth_notifier_test_support.dart';

class _SocialRepo extends FakeAuthRepository {
  _SocialRepo(this.googleResult, {this.gate});

  final Either<Failure, UserEntity> googleResult;

  /// Si se pasa, el login queda pendiente hasta que se complete.
  final Completer<void>? gate;

  /// Resultado de `/auth/me` tras el login.
  Either<Failure, UserEntity?>? meResult;
  int signOuts = 0;

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    await gate?.future;
    return googleResult;
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      meResult ?? googleResult.fold((f) => Left(f), (u) => Right(u));

  @override
  Future<Either<Failure, void>> signOut() async {
    signOuts++;
    return const Right(null);
  }
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
      await container.read(authNotifierProvider.future);

      final result = await container
          .read(authNotifierProvider.notifier)
          .signInWithGoogle();

      expect(result, SocialSignInResult.success);
      expect(container.read(authNotifierProvider).valueOrNull?.id, 'user-1');
    },
  );

  test(
    'a /auth/me failure after the social login ends the session and explains',
    () async {
      final repo = _SocialRepo(const Right(user))
        ..meResult = const Left(
          ServerFailure(message: 'RAW SERVER TEXT', code: 500),
        );
      final container = await buildAuthContainer(repo: repo);
      await container.read(authNotifierProvider.future);

      final result = await container
          .read(authNotifierProvider.notifier)
          .signInWithGoogle();

      expect(result, SocialSignInResult.failed);
      final state = container.read(authNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.valueOrNull, isNull);
      expect(state.error.toString(), isNot(contains('RAW SERVER TEXT')));
      expect(repo.signOuts, 1, reason: 'no half-logged-in session is left');
    },
  );

  test('cancel leaves the state without error and returns cancelled', () async {
    final container = await buildAuthContainer(
      repo: _SocialRepo(Left(SocialSignInCancelledFailure())),
    );
    await container.read(authNotifierProvider.future);

    final result =
        await container.read(authNotifierProvider.notifier).signInWithGoogle();

    expect(result, SocialSignInResult.cancelled);
    expect(container.read(authNotifierProvider), isNot(isA<AsyncError>()));
    expect(container.read(authNotifierProvider).valueOrNull, isNull);
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
    await container.read(authNotifierProvider.future);

    final result =
        await container.read(authNotifierProvider.notifier).signInWithGoogle();

    expect(result, SocialSignInResult.failed);
    expect(
      container.read(authNotifierProvider).error,
      'No pudimos verificar tu cuenta de Google',
    );
  });

  test(
    'never enters AsyncLoading while the native sheet is pending',
    () async {
      final gate = Completer<void>();
      final container = await buildAuthContainer(
        repo: _SocialRepo(const Right(user), gate: gate),
      );
      await container.read(authNotifierProvider.future);

      final transitions = <AsyncValue<UserEntity?>>[];
      container.listen<AsyncValue<UserEntity?>>(
        authNotifierProvider,
        (_, next) => transitions.add(next),
      );

      final pending =
          container.read(authNotifierProvider.notifier).signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      // El router manda a /splash mientras el auth está en loading, así que
      // la pantalla de login no puede quedar en loading detrás de la hoja.
      expect(container.read(authNotifierProvider).isLoading, isFalse);
      expect(transitions, isEmpty);

      gate.complete();
      await pending;

      expect(transitions.any((t) => t.isLoading), isFalse);
      expect(container.read(authNotifierProvider).valueOrNull?.id, 'user-1');
    },
  );

  test('cancel keeps the previous state untouched and never loads', () async {
    final container = await buildAuthContainer(
      repo: _SocialRepo(Left(SocialSignInCancelledFailure())),
    );
    await container.read(authNotifierProvider.future);
    final before = container.read(authNotifierProvider);

    final transitions = <AsyncValue<UserEntity?>>[];
    container.listen<AsyncValue<UserEntity?>>(
      authNotifierProvider,
      (_, next) => transitions.add(next),
    );

    await container.read(authNotifierProvider.notifier).signInWithGoogle();

    expect(transitions, isEmpty);
    expect(container.read(authNotifierProvider), same(before));
  });

  test('cancel after an earlier error clears the stale error', () async {
    final container = await buildAuthContainer(
      repo: _SocialRepo(Left(SocialSignInCancelledFailure())),
    );
    await container.read(authNotifierProvider.future);
    final notifier = container.read(authNotifierProvider.notifier);
    notifier.state = AsyncValue.error('error previo', StackTrace.current);
    expect(container.read(authNotifierProvider), isA<AsyncError>());

    final transitions = <AsyncValue<UserEntity?>>[];
    container.listen<AsyncValue<UserEntity?>>(
      authNotifierProvider,
      (_, next) => transitions.add(next),
    );

    final result = await notifier.signInWithGoogle();

    expect(result, SocialSignInResult.cancelled);
    expect(container.read(authNotifierProvider), isA<AsyncData<UserEntity?>>());
    expect(container.read(authNotifierProvider).valueOrNull, isNull);
    // Nunca pasa por loading (el router mandaría a /splash).
    expect(transitions.any((t) => t.isLoading), isFalse);
  });
}
