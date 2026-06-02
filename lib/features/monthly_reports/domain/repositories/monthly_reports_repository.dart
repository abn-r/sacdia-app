import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../entities/monthly_report.dart';

/// Repositorio de informes mensuales (interfaz del dominio)
abstract class MonthlyReportsRepository {
  /// Preview del informe para un mes/año dado.
  /// GET /api/v1/monthly-reports/preview/:enrollmentId?month=&year=
  Future<Either<Failure, MonthlyReportPreview>> getPreview(
    String enrollmentId, {
    required int month,
    required int year,
    CancelToken? cancelToken,
  });

  /// Lista de informes de un enrollment.
  /// GET /api/v1/monthly-reports/enrollment/:enrollmentId
  Future<Either<Failure, List<MonthlyReport>>> getReportsByEnrollment(
      String enrollmentId,
      {CancelToken? cancelToken});

  /// Detalle de un informe.
  /// GET /api/v1/monthly-reports/:reportId
  Future<Either<Failure, MonthlyReport>> getReportDetail(String reportId,
      {CancelToken? cancelToken});

  /// Obtiene o crea el borrador de un informe mensual.
  /// POST /api/v1/monthly-reports/:enrollmentId?month=&year=
  Future<Either<Failure, MonthlyReport>> getOrCreateDraft(
    String enrollmentId, {
    required int month,
    required int year,
    CancelToken? cancelToken,
  });

  /// Guarda los campos manuales del informe.
  /// PATCH /api/v1/monthly-reports/:reportId/manual-data
  Future<Either<Failure, MonthlyReport>> updateManualData(
    String reportId,
    MonthlyReportManualData manualData, {
    CancelToken? cancelToken,
  });

  /// Listado jerárquico de reportes visibles para el usuario autenticado.
  /// GET /api/v1/monthly-reports/admin/list
  Future<Either<Failure, VisibleMonthlyReportsPage>> getVisibleReports({
    int page,
    int limit,
    CancelToken? cancelToken,
  });

  /// Downloads the monthly report PDF via the authenticated HTTP client and
  /// returns the local file path of the saved temporary file.
  /// GET /api/v1/monthly-reports/:reportId/pdf
  ///
  /// The Bearer token is sent in the Authorization header — never in the URL.
  /// This call is intentionally separate from getReportDetail because the
  /// detail response contains no pdfUrl field; the PDF is generated on demand
  /// server-side.
  Future<Either<Failure, String>> downloadReportPdf(String reportId,
      {CancelToken? cancelToken});
}
