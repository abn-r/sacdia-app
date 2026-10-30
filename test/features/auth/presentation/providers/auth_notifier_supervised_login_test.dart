import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/login_notice_provider.dart';

import 'auth_notifier_test_support.dart';

const _teen = UserEntity(
  id: 'teen-1',
  name: 'Ana',
  postRegisterComplete: true,
);

class _Repo extends FakeAuthRepository {
  _Repo(this.signInResult);

  Either<Failure, UserEntity> signInResult;
  final identifiers = <String>[];
  bool signedIn = false;

  @override
  Future<bool> hasLocalToken() async => signedIn;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      signedIn ? const Right(_teen) : const Right(null);

  @override
  Future<Either<Failure, UserEntity>> signInWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    identifiers.add(identifier);
    if (signInResult.isRight()) signedIn = true;
    return signInResult;
  }
}

void main() {
  group('signIn with an identifier', () {
    test('passes the handle through untouched and succeeds', () async {
      final repo = _Repo(const Right(_teen));
      final container = await buildAuthContainer(repo: repo);
      await container.read(authNotifierProvider.future);

      final ok = await container
          .read(authNotifierProvider.notifier)
          .signIn(identifier: 'ana-7kq4m9', password: 'Password123');

      expect(ok, isTrue);
      expect(repo.identifiers, ['ana-7kq4m9']);
      expect(container.read(authNotifierProvider).valueOrNull?.id, 'teen-1');
    });

    test('a failure leaves a message keyed by the business code, not raw text',
        () async {
      final repo = _Repo(const Left(
        AuthFailure(
          message: 'RAW SERVER TEXT',
          code: 403,
          errorCode: 'AUTH_SUPERVISED_LOGIN_DISABLED',
        ),
      ));
      final container = await buildAuthContainer(repo: repo);
      await container.read(authNotifierProvider.future);

      final ok = await container
          .read(authNotifierProvider.notifier)
          .signIn(identifier: 'ana-7kq4m9', password: 'Password123');

      expect(ok, isFalse);
      final state = container.read(authNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error.toString(), isNot(contains('RAW SERVER TEXT')));
    });

    test('a new attempt clears the pending revoked-access notice', () async {
      final repo = _Repo(const Right(_teen));
      final container = await buildAuthContainer(repo: repo);
      await container.read(authNotifierProvider.future);
      container.read(loginNoticeProvider.notifier).state =
          LoginNotice.supervisedAccessRevoked;

      await container
          .read(authNotifierProvider.notifier)
          .signIn(identifier: 'ana-7kq4m9', password: 'Password123');

      expect(container.read(loginNoticeProvider), isNull);
    });
  });

  group('revoked supervised access', () {
    test('ends the local session, wipes cached identity and leaves a notice',
        () async {
      final repo = _Repo(const Right(_teen))..signedIn = true;
      final storage = FakeSecureStorage();
      await storage.write(AppConstants.cachedUserId, 'teen-1');
      await storage.write(AppConstants.cachedUserName, 'Ana');
      await storage.write(AppConstants.cachedActiveAssignmentId, 'a-1');
      final container = await buildAuthContainer(repo: repo, storage: storage);
      expect(
        (await container.read(authNotifierProvider.future))?.id,
        'teen-1',
      );

      container.read(authNotifierProvider.notifier).onSupervisedAccessRevoked();

      expect(container.read(authNotifierProvider).valueOrNull, isNull);
      expect(
        container.read(loginNoticeProvider),
        LoginNotice.supervisedAccessRevoked,
      );
      expect(await storage.read(AppConstants.cachedUserId), isNull);
      expect(await storage.read(AppConstants.cachedUserName), isNull);
      expect(await storage.read(AppConstants.cachedActiveAssignmentId), isNull);
    });
  });
}
