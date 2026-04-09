import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart' as core_exceptions;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/completion_status.dart';
import '../../domain/repositories/post_registration_repository.dart';
import '../datasources/post_registration_remote_data_source.dart';

/// Implementación del repositorio de post-registro
class PostRegistrationRepositoryImpl implements PostRegistrationRepository {
  final PostRegistrationRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  PostRegistrationRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, CompletionStatus>> getCompletionStatus({
    CancelToken? cancelToken,
  }) async {
    try {
      final status = await remoteDataSource.getCompletionStatus(
        cancelToken: cancelToken,
      );
      return Right(status);
    } on core_exceptions.ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on core_exceptions.AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadProfilePicture({
    required String userId,
    required String filePath,
  }) async {
    try {
      final url = await remoteDataSource.uploadProfilePicture(
        userId: userId,
        filePath: filePath,
      );
      return Right(url);
    } on core_exceptions.ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on core_exceptions.AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProfilePicture({
    required String userId,
  }) async {
    try {
      await remoteDataSource.deleteProfilePicture(userId: userId);
      return const Right(null);
    } on core_exceptions.ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on core_exceptions.AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> getPhotoStatus({
    required String userId,
    CancelToken? cancelToken,
  }) async {
    try {
      final hasPhoto = await remoteDataSource.getPhotoStatus(
        userId: userId,
        cancelToken: cancelToken,
      );
      return Right(hasPhoto);
    } on core_exceptions.ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on core_exceptions.AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> completeStep1(String userId) async {
    try {
      await remoteDataSource.completeStep1(userId);
      return const Right(null);
    } on core_exceptions.ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on core_exceptions.AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
