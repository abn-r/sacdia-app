import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/supervision_request.dart';
import '../../domain/repositories/supervision_requests_repository.dart';
import '../datasources/supervision_requests_remote_data_source.dart';

class SupervisionRequestsRepositoryImpl
    implements SupervisionRequestsRepository {
  SupervisionRequestsRepositoryImpl({required this.remoteDataSource});

  final SupervisionRequestsRemoteDataSource remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
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

  @override
  Future<Either<Failure, List<SupervisionRequest>>> getRequests({
    required SupervisionRequestKind kind,
    required SupervisionRequestStatus status,
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() async => await remoteDataSource.getRequests(
            kind: kind,
            status: status,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, SupervisionRequest>> review({
    required SupervisionRequestKind kind,
    required String requestId,
    required bool approve,
    String? comment,
  }) =>
      _guard<SupervisionRequest>(() => remoteDataSource.review(
            kind: kind,
            requestId: requestId,
            approve: approve,
            comment: comment,
          ));
}
