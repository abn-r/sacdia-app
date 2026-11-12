import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/coordinator_report.dart';
import '../entities/report_compliance.dart';

/// Read-only monthly club reports of the coordinator's scope. There is no finalize,
/// regenerate or submit here on purpose: coordinators review, they do not run
/// the clubs' reports.
abstract class CoordinatorReportsRepository {
  /// GET /reports/compliance (active ecclesiastical year).
  Future<Either<Failure, ReportCompliance>> getCompliance({
    int? year,
    int? month,
    RequestCancelToken? cancelToken,
  });

  /// Admin list of monthly reports narrowed to one month.
  Future<Either<Failure, List<CoordinatorReport>>> listReports({
    int? year,
    int? period,
    RequestCancelToken? cancelToken,
  });

  /// Local path of the downloaded PDF.
  Future<Either<Failure, String>> downloadReportPdf({
    required int reportId,
    RequestCancelToken? cancelToken,
  });
}
