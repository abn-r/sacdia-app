import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

/// Implementación del repositorio de perfil
class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, UserDetail>> getUserProfile(String userId) async {
    if (await networkInfo.isConnected) {
      try {
        final userDetail = await remoteDataSource.getUserProfile(userId);
        return Right(userDetail);
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(UnexpectedFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }

  @override
  Future<Either<Failure, UserDetail>> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final userDetail = await remoteDataSource.updateUserProfile(userId, data);
        return Right(userDetail);
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(UnexpectedFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }

  @override
  Future<Either<Failure, String>> updateProfilePicture(
    String userId,
    String filePath,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final imageUrl = await remoteDataSource.updateProfilePicture(userId, filePath);
        return Right(imageUrl);
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message, code: e.code));
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(UnexpectedFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
  }
}
