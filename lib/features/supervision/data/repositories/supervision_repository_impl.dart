import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/supervision_pending_counts.dart';
import '../../domain/repositories/supervision_repository.dart';
import '../datasources/supervision_remote_data_source.dart';

class SupervisionRepositoryImpl implements SupervisionRepository {
  final SupervisionRemoteDataSource remoteDataSource;

  SupervisionRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, SupervisionPendingCounts>> getPendingCounts({
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getPendingCounts(
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return Right(model);
    } on ServerException catch (e) {
      return Left(ServerFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on AuthException catch (e) {
      return Left(AuthFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
