import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/supervision_enrollment.dart';
import '../../domain/repositories/supervision_enrollments_repository.dart';
import '../datasources/supervision_enrollments_remote_data_source.dart';

class SupervisionEnrollmentsRepositoryImpl
    implements SupervisionEnrollmentsRepository {
  final SupervisionEnrollmentsRemoteDataSource remoteDataSource;

  SupervisionEnrollmentsRepositoryImpl({required this.remoteDataSource});

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
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

  @override
  Future<Either<Failure, SupervisionEnrollmentPage>> getQueue({
    SupervisionEnrollmentStatus status =
        SupervisionEnrollmentStatus.pendingValidation,
    String? search,
    int page = 1,
    int limit = 20,
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getQueue(
            status: status,
            search: search,
            page: page,
            limit: limit,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, SupervisionEnrollment>> approve(
    String enrollmentId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.approve(
            enrollmentId,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, SupervisionEnrollment>> reject(
    String enrollmentId,
    String reason, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.reject(
            enrollmentId,
            reason,
            cancelToken: cancelToken.asDioCancelToken(),
          ));
}
