import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart' as core_exceptions;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

/// Implementación del repositorio de autenticación
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Stream<bool> get authStateChanges => remoteDataSource.authStateChanges;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    if (await networkInfo.isConnected) {
      try {
        final userModel = await remoteDataSource.getCurrentUser();
        return Right(userModel);
      } on core_exceptions.AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return Right(user);
      } on core_exceptions.AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.signUpWithEmailAndPassword(
          email: email,
          password: password,
          name: name,
          paternalSurname: paternalSurname,
          maternalSurname: maternalSurname,
        );
        return Right(user);
      } on core_exceptions.AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    // Logout is fail-safe: always clear local session regardless of network
    // state or server response. We still attempt the API call when online,
    // but a network error must never block the user from logging out.
    try {
      await remoteDataSource.signOut();
    } catch (_) {
      // Swallow any exception — local state is already cleared inside signOut.
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.resetPassword(email);
        return const Right(null);
      } on core_exceptions.AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> updatePassword(String newPassword) async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.updatePassword(newPassword);
        return Right(user);
      } on core_exceptions.AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.signInWithGoogle();
        return Right(user);
      } on core_exceptions.OAuthFlowInitiatedException catch (e) {
        return Left(OAuthFlowInitiatedFailure(provider: e.provider));
      } on core_exceptions.AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithApple() async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.signInWithApple();
        return Right(user);
      } on core_exceptions.OAuthFlowInitiatedException catch (e) {
        return Left(OAuthFlowInitiatedFailure(provider: e.provider));
      } on core_exceptions.AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> handleOAuthCallback({
    required String sessionToken,
    required String provider,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.handleOAuthCallback(
          sessionToken: sessionToken,
          provider: provider,
        );
        return Right(user);
      } on core_exceptions.AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }

  @override
  Future<bool> hasLocalToken() async {
    return remoteDataSource.hasLocalToken();
  }

  @override
  Future<Either<Failure, void>> switchContext(String assignmentId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.switchContext(assignmentId);
        return const Right(null);
      } on core_exceptions.AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }

  @override
  Future<Either<Failure, bool>> getCompletionStatus() async {
    if (await networkInfo.isConnected) {
      try {
        final status = await remoteDataSource.getCompletionStatus();
        return Right(status);
      } on core_exceptions.AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }
}
