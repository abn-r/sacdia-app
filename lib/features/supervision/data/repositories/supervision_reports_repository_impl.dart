import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/supervision_report.dart';
import '../../domain/repositories/supervision_reports_repository.dart';
import '../datasources/supervision_reports_remote_data_source.dart';

class SupervisionReportsRepositoryImpl implements SupervisionReportsRepository {
  final SupervisionReportsRemoteDataSource remoteDataSource;

  SupervisionReportsRepositoryImpl({required this.remoteDataSource});

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
  Future<Either<Failure, SupervisionReportPeriods>> getPeriods({
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getPeriods(
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, SupervisionCompliancePage>> getCompliance({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getCompliance(
            period: period,
            page: page,
            limit: limit,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, SupervisionReportPage>> getReports({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getReports(
            period: period,
            page: page,
            limit: limit,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, String>> downloadReportPdf(
    String reportId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.downloadReportPdf(
            reportId,
            cancelToken: cancelToken.asDioCancelToken(),
          ));
}
