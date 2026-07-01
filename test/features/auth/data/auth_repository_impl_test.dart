import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart' as core_exceptions;
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sacdia_app/features/auth/data/models/user_model.dart';
import 'package:sacdia_app/features/auth/data/repositories/auth_repository_impl.dart';

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
  Future<UserModel> handleOAuthCallback({
    required String sessionToken,
    required String provider,
  }) =>
      throw UnimplementedError();

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

  @override
  Future<UserModel> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
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
  Future<void> deleteAccount(String password) => throw UnimplementedError();
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
}
