import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/errors/exceptions.dart' as core_exceptions;
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sacdia_app/features/auth/data/models/user_model.dart';
import 'package:sacdia_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sacdia_app/features/auth/domain/entities/delete_account_reauth.dart';

class _FakeNetworkInfo implements NetworkInfo {
  _FakeNetworkInfo(this.connected);

  final bool connected;

  @override
  Future<bool> get isConnected async => connected;
}

class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  _FakeAuthRemoteDataSource({
    required this.getCurrentUserHandler,
  });

  final Future<UserModel?> Function() getCurrentUserHandler;
  int getCurrentUserCalls = 0;

  @override
  Stream<bool> get authStateChanges => Stream.value(true);

  @override
  Future<UserModel?> getCurrentUser() async {
    getCurrentUserCalls += 1;
    return getCurrentUserHandler();
  }

  @override
  Future<bool> hasLocalToken() => throw UnimplementedError();

  @override
  Future<void> resetPassword(String email) => throw UnimplementedError();

  @override
  Future<UserModel> signInWithApple() => throw UnimplementedError();

  @override
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  Future<UserModel> Function()? signInWithGoogleHandler;

  @override
  Future<UserModel> signInWithGoogle() =>
      signInWithGoogleHandler?.call() ?? (throw UnimplementedError());

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
    required String acceptedTermsVersion,
    required String acceptedPrivacyVersion,
    String? birthday,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> switchContext(String assignmentId) => throw UnimplementedError();

  @override
  Future<UserModel> updatePassword(
    String currentPassword,
    String newPassword,
  ) =>
      throw UnimplementedError();

  @override
  Future<bool> getCompletionStatus() => throw UnimplementedError();

  @override
  Future<void> deleteAccount(DeleteAccountReauth reauth) {
    deleteAccountReauth = reauth;
    return deleteAccountHandler?.call() ?? (throw UnimplementedError());
  }

  DeleteAccountReauth? deleteAccountReauth;
  Future<void> Function()? deleteAccountHandler;
  Future<List<SocialProvider>> Function()? getConnectedProvidersHandler;

  @override
  Future<List<SocialProvider>> getConnectedProviders() =>
      getConnectedProvidersHandler?.call() ?? (throw UnimplementedError());
}

void main() {
  group('AuthRepositoryImpl.getCurrentUser', () {
    test('returns NetworkFailure without touching remote when offline',
        () async {
      final remoteDataSource = _FakeAuthRemoteDataSource(
        getCurrentUserHandler: () async {
          throw StateError('remote should not be called while offline');
        },
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: remoteDataSource,
        networkInfo: _FakeNetworkInfo(false),
      );

      final result = await repository.getCurrentUser();

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Expected NetworkFailure'),
      );
      expect(remoteDataSource.getCurrentUserCalls, 0);
    });

    test('maps connection exceptions to NetworkFailure', () async {
      final remoteDataSource = _FakeAuthRemoteDataSource(
        getCurrentUserHandler: () async {
          throw core_exceptions.ConnectionException(message: 'offline');
        },
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: remoteDataSource,
        networkInfo: _FakeNetworkInfo(true),
      );

      final result = await repository.getCurrentUser();

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Expected NetworkFailure'),
      );
      expect(remoteDataSource.getCurrentUserCalls, 1);
    });
  });

  group('signInWithGoogle', () {
    test('maps a cancel to SocialSignInCancelledFailure', () async {
      final ds = _FakeAuthRemoteDataSource(
        getCurrentUserHandler: () async => null,
      )..signInWithGoogleHandler =
          () async => throw core_exceptions.SocialSignInCancelledException();
      final repo = AuthRepositoryImpl(
        remoteDataSource: ds,
        networkInfo: _FakeNetworkInfo(true),
      );

      final result = await repo.signInWithGoogle();

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<SocialSignInCancelledFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('deleteAccount / getConnectedProviders', () {
    AuthRepositoryImpl build(_FakeAuthRemoteDataSource ds) =>
        AuthRepositoryImpl(
          remoteDataSource: ds,
          networkInfo: _FakeNetworkInfo(true),
        );

    _FakeAuthRemoteDataSource fake() =>
        _FakeAuthRemoteDataSource(getCurrentUserHandler: () async => null);

    test('deleteAccount hands the reauth to the datasource', () async {
      final ds = fake()..deleteAccountHandler = () async {};
      const reauth = PasswordReauth('pw');

      final result = await build(ds).deleteAccount(reauth);

      expect(result.isRight(), isTrue);
      expect(ds.deleteAccountReauth, same(reauth));
    });

    test('deleteAccount maps an AuthException to AuthFailure with its code',
        () async {
      final ds = fake()
        ..deleteAccountHandler =
            () async => throw core_exceptions.AuthException(
                  message: 'nope',
                  code: 401,
                );

      final result = await build(ds).deleteAccount(const PasswordReauth('pw'));

      result.fold(
        (f) {
          expect(f, isA<AuthFailure>());
          expect((f as AuthFailure).message, 'nope');
          expect(f.code, 401);
        },
        (_) => fail('expected Left'),
      );
    });

    test('getConnectedProviders returns the datasource list', () async {
      final ds = fake()
        ..getConnectedProvidersHandler =
            () async => [SocialProvider.google, SocialProvider.apple];

      final result = await build(ds).getConnectedProviders();

      expect(
        result.getOrElse(() => const []),
        [SocialProvider.google, SocialProvider.apple],
      );
    });

    test('getConnectedProviders maps failures to Left', () async {
      final ds = fake()
        ..getConnectedProvidersHandler =
            () async => throw core_exceptions.AuthException(message: 'x');

      final result = await build(ds).getConnectedProviders();

      expect(result.isLeft(), isTrue);
    });
  });
}
