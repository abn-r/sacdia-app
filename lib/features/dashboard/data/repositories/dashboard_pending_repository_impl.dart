import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/dashboard_pending.dart';
import '../../domain/repositories/dashboard_pending_repository.dart';
import '../datasources/dashboard_pending_remote_data_source.dart';

class DashboardPendingRepositoryImpl implements DashboardPendingRepository {
  DashboardPendingRepositoryImpl({required this.remoteDataSource});

  final DashboardPendingRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, DashboardPending>> getPending({
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final pending = await remoteDataSource.getPending(
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return Right(pending);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
