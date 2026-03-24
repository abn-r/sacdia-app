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

  /// URL para descargar el PDF de un informe.
  /// GET /api/v1/monthly-reports/:reportId/pdf
  Future<Either<Failure, String>> getReportPdfUrl(int reportId);
}
