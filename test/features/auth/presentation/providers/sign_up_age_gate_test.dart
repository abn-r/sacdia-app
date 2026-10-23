import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/registration_age_gate.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import 'auth_notifier_test_support.dart';

class _SignUpRepo extends FakeAuthRepository {
  _SignUpRepo(this.result);

  final Either<Failure, UserEntity> result;
  final birthdays = <String?>[];

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
    required String acceptedTermsVersion,
    required String acceptedPrivacyVersion,
    String? birthday,
  }) async {
    birthdays.add(birthday);
    return result;
  }
}

Future<bool> _signUp(ProviderContainer c) =>
    c.read(authNotifierProvider.notifier).signUp(
          email: 'ana@example.com',
          password: 'Password123',
          name: 'Ana',
          paternalSurname: 'Perez',
          maternalSurname: 'Lopez',
          acceptedTermsVersion: '1.0.0',
          acceptedPrivacyVersion: '1.0.0',
          birthday: '2000-01-02',
        );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> build(_SignUpRepo repo) async {
    final container = await buildAuthContainer(repo: repo);
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    return container;
  }

  test('forwards the birthday to the repository', () async {
    final repo = _SignUpRepo(const Right(UserEntity(id: 'u1', name: 'Ana')));
    final container = await build(repo);

    final ok = await _signUp(container);

    expect(ok, isTrue);
    expect(repo.birthdays, ['2000-01-02']);
  });

  test('AUTH_REGISTRATION_AGE_BELOW_MINIMUM becomes the typed age error',
      () async {
    final repo = _SignUpRepo(
      const Left(
        AuthFailure(
          message: 'server text',
          code: 422,
          errorCode: kRegistrationAgeBelowMinimumCode,
        ),
      ),
    );
    final container = await build(repo);

    final ok = await _signUp(container);

    expect(ok, isFalse);
    expect(
      container.read(authNotifierProvider).error,
      isA<RegistrationAgeBelowMinimum>(),
    );
  });

  test('any other failure keeps the plain message', () async {
    final repo = _SignUpRepo(
      const Left(AuthFailure(message: 'Email ya registrado', code: 409)),
    );
    final container = await build(repo);

    final ok = await _signUp(container);

    expect(ok, isFalse);
    expect(container.read(authNotifierProvider).error, 'Email ya registrado');
  });
}
