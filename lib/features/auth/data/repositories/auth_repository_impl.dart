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
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.signOut();
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
}
