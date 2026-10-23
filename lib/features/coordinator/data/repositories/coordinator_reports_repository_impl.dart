import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/coordinator_report.dart';
import '../../domain/entities/report_compliance.dart';
import '../../domain/repositories/coordinator_reports_repository.dart';
import '../datasources/coordinator_reports_remote_data_source.dart';

class CoordinatorReportsRepositoryImpl implements CoordinatorReportsRepository {
  CoordinatorReportsRepositoryImpl({required this.remoteDataSource});

  final CoordinatorReportsRemoteDataSource remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReportCompliance>> getCompliance({
    int? year,
    int? month,
    int? quarter,
    RequestCancelToken? cancelToken,
  }) =>
      _guard(
        () => remoteDataSource.getCompliance(
          year: year,
          month: month,
          quarter: quarter,
          cancelToken: cancelToken.asDioCancelToken(),
        ),
      );

  @override
  Future<Either<Failure, List<CoordinatorReport>>> listReports({
    required CoordinatorReportKind kind,
    int? year,
    int? period,
    int? ecclesiasticalYearId,
    RequestCancelToken? cancelToken,
  }) =>
      _guard(
        () => remoteDataSource.listReports(
          kind: kind,
          year: year,
          period: period,
          ecclesiasticalYearId: ecclesiasticalYearId,
          cancelToken: cancelToken.asDioCancelToken(),
        ),
      );

  @override
  Future<Either<Failure, String>> downloadReportPdf({
    required CoordinatorReportKind kind,
    required int reportId,
    RequestCancelToken? cancelToken,
  }) =>
      _guard(
        () => remoteDataSource.downloadReportPdf(
          kind: kind,
          reportId: reportId,
          cancelToken: cancelToken.asDioCancelToken(),
        ),
      );
}
