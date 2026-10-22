import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/coordinator_report.dart';
import '../entities/report_compliance.dart';

/// Read-only club reports of the coordinator's scope. There is no finalize,
/// regenerate or submit here on purpose: coordinators review, they do not run
/// the clubs' reports.
abstract class CoordinatorReportsRepository {
  /// GET /reports/compliance (active ecclesiastical year).
  Future<Either<Failure, ReportCompliance>> getCompliance({
    int? year,
    int? month,
    int? quarter,
    RequestCancelToken? cancelToken,
  });

  /// Admin list of [kind] reports narrowed to one period.
  Future<Either<Failure, List<CoordinatorReport>>> listReports({
    required CoordinatorReportKind kind,
    int? year,
    int? period,
    int? ecclesiasticalYearId,
    RequestCancelToken? cancelToken,
  });

  /// Local path of the downloaded PDF.
  Future<Either<Failure, String>> downloadReportPdf({
    required CoordinatorReportKind kind,
    required int reportId,
    RequestCancelToken? cancelToken,
  });
}
