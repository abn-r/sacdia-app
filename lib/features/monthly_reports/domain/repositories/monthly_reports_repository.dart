import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/monthly_report.dart';

/// Repositorio de informes mensuales (interfaz del dominio)
abstract class MonthlyReportsRepository {
  /// Preview del informe para un mes/año dado.
  /// GET /api/v1/monthly-reports/preview/:enrollmentId?month=&year=
  Future<Either<Failure, MonthlyReportPreview>> getPreview(
    int enrollmentId, {
    required int month,
    required int year,
  });

  /// Lista de informes de un enrollment.
  /// GET /api/v1/monthly-reports/enrollment/:enrollmentId
  Future<Either<Failure, List<MonthlyReport>>> getReportsByEnrollment(
      int enrollmentId);

  /// Detalle de un informe.
  /// GET /api/v1/monthly-reports/:reportId
  Future<Either<Failure, MonthlyReport>> getReportDetail(int reportId);

  /// Constructs the authenticated URL for downloading the monthly report PDF.
  /// GET /api/v1/monthly-reports/:reportId/pdf
  ///
  /// The backend endpoint streams raw PDF bytes (application/pdf) directly —
  /// it does not return a signed URL or a JSON payload. The data source
  /// constructs a URL with the auth token appended as a query parameter so
  /// url_launcher can open it in an external browser/viewer. This call is
  /// intentionally separate from getReportDetail because the detail response
  /// contains no pdfUrl field; the PDF is generated on demand server-side.
  Future<Either<Failure, String>> getReportPdfUrl(int reportId);
}
