import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/monthly_reports_remote_data_source.dart';
import '../../data/repositories/monthly_reports_repository_impl.dart';
import '../../domain/entities/monthly_report.dart';
import '../../domain/repositories/monthly_reports_repository.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final monthlyReportsRemoteDataSourceProvider =
    Provider<MonthlyReportsRemoteDataSource>((ref) {
  return MonthlyReportsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final monthlyReportsRepositoryProvider =
    Provider<MonthlyReportsRepository>((ref) {
  return MonthlyReportsRepositoryImpl(
    remoteDataSource: ref.read(monthlyReportsRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Preview params ────────────────────────────────────────────────────────────

class MonthlyReportPreviewParams {
  final int enrollmentId;
  final int month;
  final int year;

  const MonthlyReportPreviewParams({
    required this.enrollmentId,
    required this.month,
    required this.year,
  });

  @override
  bool operator ==(Object other) =>
      other is MonthlyReportPreviewParams &&
      other.enrollmentId == enrollmentId &&
      other.month == month &&
      other.year == year;

  @override
  int get hashCode => Object.hash(enrollmentId, month, year);
}

// ── Data providers ────────────────────────────────────────────────────────────

/// Preview del informe mensual para un enrollment/mes/año.
final monthlyReportPreviewProvider = FutureProvider.autoDispose
    .family<MonthlyReportPreview, MonthlyReportPreviewParams>(
        (ref, params) async {
  final repo = ref.read(monthlyReportsRepositoryProvider);
  final result = await repo.getPreview(
    params.enrollmentId,
    month: params.month,
    year: params.year,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (preview) => preview,
  );
});

/// Lista de informes mensuales de un enrollment.
final monthlyReportsByEnrollmentProvider =
    FutureProvider.autoDispose.family<List<MonthlyReport>, int>(
        (ref, enrollmentId) async {
  final repo = ref.read(monthlyReportsRepositoryProvider);
  final result = await repo.getReportsByEnrollment(enrollmentId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (reports) => reports,
  );
});

/// Detalle de un informe mensual.
final monthlyReportDetailProvider =
    FutureProvider.autoDispose.family<MonthlyReport, int>(
        (ref, reportId) async {
  final repo = ref.read(monthlyReportsRepositoryProvider);
  final result = await repo.getReportDetail(reportId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (report) => report,
  );
});

/// Descarga el PDF de un informe mensual y devuelve la ruta local del archivo
/// temporal. El token JWT se envía en el header Authorization — nunca en la URL.
final monthlyReportPdfProvider =
    FutureProvider.autoDispose.family<String, int>((ref, reportId) async {
  final repo = ref.read(monthlyReportsRepositoryProvider);
  final result = await repo.downloadReportPdf(reportId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (localPath) => localPath,
  );
});
