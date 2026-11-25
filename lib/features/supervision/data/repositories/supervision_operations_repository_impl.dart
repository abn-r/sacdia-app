import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/supervision_operations.dart';
import '../../domain/repositories/supervision_operations_repository.dart';
import '../datasources/supervision_operations_remote_data_source.dart';

class SupervisionOperationsRepositoryImpl
    implements SupervisionOperationsRepository {
  final SupervisionOperationsRemoteDataSource remoteDataSource;

  SupervisionOperationsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, SupervisionOperationsDashboard>> getDashboard(
    SupervisionOperationsQuery query, {
    RequestCancelToken? cancelToken,
  }) async {
    try {
      return Right(await remoteDataSource.getDashboard(
        query,
        cancelToken: cancelToken.asDioCancelToken(),
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on AuthException catch (e) {
      return Left(AuthFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on ConnectionException catch (e) {
      return Left(ConnectionFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
