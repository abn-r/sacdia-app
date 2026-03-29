import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/validation.dart';
import '../../domain/repositories/validation_repository.dart';
import '../datasources/validation_remote_data_source.dart';

class ValidationRepositoryImpl implements ValidationRepository {
  final ValidationRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  const ValidationRepositoryImpl({
    required ValidationRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

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
  }) async {
    try {
      final models = await _remoteDataSource.getValidationHistory(
        entityType: entityType,
        entityId: entityId,
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
  }) async {
    try {
      final model = await _remoteDataSource.checkEligibility(userId: userId);
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
