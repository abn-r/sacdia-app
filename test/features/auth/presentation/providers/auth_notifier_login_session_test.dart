import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/login_notice_provider.dart';

import 'auth_notifier_test_support.dart';

/// Un login correcto solo vale si `/auth/me` también responde: si no, no queda
/// una sesión a medias y la persona ve por qué.

const _loginUser = UserEntity(id: 'u1', email: 'u1@example.com', name: 'Ana');
const _meUser = UserEntity(
  id: 'u1',
  email: 'u1@example.com',
  name: 'Ana',
  postRegisterComplete: true,
);

class _Repo extends FakeAuthRepository {
  Either<Failure, UserEntity?> me = const Right(_meUser);
  int meCalls = 0;
  int signOuts = 0;
  bool signedIn = false;

  @override
  Future<bool> hasLocalToken() async => signedIn;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    meCalls++;
    return me;
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    signedIn = true;
    return const Right(_loginUser);
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    signOuts++;
    signedIn = false;
    return const Right(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({_Repo repo, ProviderContainer container, AuthNotifier auth})>
      setUp() async {
    final repo = _Repo();
    final container = await buildAuthContainer(repo: repo);
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    return (
      repo: repo,
      container: container,
      auth: container.read(authNotifierProvider.notifier),
    );
  }

  AsyncValueLike read(ProviderContainer c) =>
      AsyncValueLike(c.read(authNotifierProvider));

  test('success publishes the /auth/me user (not the thin login user)',
      () async {
    final h = await setUp();

    final ok = await h.auth.signIn(identifier: 'ana@x.com', password: 'pw');

    expect(ok, isTrue);
    expect(h.repo.meCalls, 1);
    final user = read(h.container).user!;
    expect(user.postRegisterComplete, isTrue);
    expect(h.container.read(lastLoginIdentifierProvider), '',
        reason: 'cleared once the login is complete');
  });

  test('a /auth/me 500 shows a server error, keeps the email, ends the session',
      () async {
    final h = await setUp();
    h.repo.me = const Left(
      ServerFailure(message: 'RAW SERVER TEXT', code: 500),
    );

    final ok = await h.auth.signIn(identifier: 'ana@x.com', password: 'pw');

    expect(ok, isFalse);
    final state = read(h.container);
    expect(state.user, isNull);
    expect(state.error, isNotNull);
    expect(state.error, isNot(contains('RAW SERVER TEXT')));
    // Sin EasyLocalization montada `tr()` devuelve la clave: aquí se prueba QUÉ
    // mensaje se elige; el texto traducido se ve en el test de la vista.
    expect(state.error, 'auth.errors.session_load_failed');
    expect(h.repo.signOuts, 1, reason: 'no half-logged-in session is left');
    expect(h.container.read(lastLoginIdentifierProvider), 'ana@x.com');
  });

  test('a /auth/me connection failure reads as a connection error', () async {
    final h = await setUp();
    h.repo.me = const Left(NetworkFailure(message: 'Sin conexión a internet'));

    final ok = await h.auth.signIn(identifier: 'ana@x.com', password: 'pw');

    expect(ok, isFalse);
    expect(read(h.container).error, 'errors.connection_error');
    expect(h.repo.signOuts, 1);
  });

  test(
      'an empty /auth/me (token rejected) is also an error, not a silent '
      'form reset', () async {
    final h = await setUp();
    h.repo.me = const Right(null);

    final ok = await h.auth.signIn(identifier: 'ana@x.com', password: 'pw');

    expect(ok, isFalse);
    expect(read(h.container).user, isNull);
    expect(read(h.container).error, isNotNull);
    expect(h.repo.signOuts, 1);
  });

  test('a later successful login after a failure works', () async {
    final h = await setUp();
    h.repo.me = const Left(ServerFailure(message: 'x', code: 500));
    await h.auth.signIn(identifier: 'ana@x.com', password: 'pw');

    h.repo.me = const Right(_meUser);
    final ok = await h.auth.signIn(identifier: 'ana@x.com', password: 'pw');

    expect(ok, isTrue);
    expect(read(h.container).user!.id, 'u1');
    expect(h.container.read(lastLoginIdentifierProvider), '');
  });
}

/// Lectura mínima del estado de auth: usuario y mensaje de error.
class AsyncValueLike {
  AsyncValueLike(this._value);

  final AsyncValue<UserEntity?> _value;

  UserEntity? get user => _value.valueOrNull;
  String? get error => _value.hasError ? _value.error as String : null;
}
