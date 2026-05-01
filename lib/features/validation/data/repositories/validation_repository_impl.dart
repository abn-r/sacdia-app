import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/validation.dart';
import '../../domain/repositories/validation_repository.dart';
import '../datasources/validation_remote_data_source.dart';

class ValidationRepositoryImpl implements ValidationRepository {
  final ValidationRemoteDataSource _remoteDataSource;

  const ValidationRepositoryImpl({
    required ValidationRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, ValidationSubmitResult>> submitForReview({
    required ValidationEntityType entityType,
    required int entityId,
  }) async {
    try {
      final model = await _remoteDataSource.submitForReview(
        entityType: entityType,
        entityId: entityId,
      );
      return Right(model);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ValidationHistoryEntry>>> getValidationHistory({
    required ValidationEntityType entityType,
    required int entityId,
    CancelToken? cancelToken,
  }) async {
    try {
      final models = await _remoteDataSource.getValidationHistory(
        entityType: entityType,
        entityId: entityId,
        cancelToken: cancelToken,
      );
      return Right(models);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, EligibilityResult>> checkEligibility({
    required String userId,
    CancelToken? cancelToken,
  }) async {
    try {
      final model = await _remoteDataSource.checkEligibility(
        userId: userId,
        cancelToken: cancelToken,
      );
      return Right(model);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
