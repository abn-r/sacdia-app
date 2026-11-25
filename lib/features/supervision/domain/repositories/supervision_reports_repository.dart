import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/supervision_report.dart';

abstract class SupervisionReportsRepository {
  /// GET /reports/compliance (months of the active year).
  Future<Either<Failure, SupervisionReportPeriods>> getPeriods({
    RequestCancelToken? cancelToken,
  });

  /// GET /reports/compliance for one month.
  Future<Either<Failure, SupervisionCompliancePage>> getCompliance({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  });

  /// GET /monthly-reports/admin/list for one month.
  Future<Either<Failure, SupervisionReportPage>> getReports({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  });

  /// GET /monthly-reports/:reportId/pdf; right value is the local file path.
  Future<Either<Failure, String>> downloadReportPdf(
    String reportId, {
    RequestCancelToken? cancelToken,
  });
}
