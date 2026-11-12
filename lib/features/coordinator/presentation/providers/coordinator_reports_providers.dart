import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/coordinator_reports_remote_data_source.dart';
import '../../data/repositories/coordinator_reports_repository_impl.dart';
import '../../domain/entities/coordinator_report.dart';
import '../../domain/entities/report_compliance.dart';
import '../../domain/repositories/coordinator_reports_repository.dart';
import 'coordinator_providers.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final coordinatorReportsRemoteDataSourceProvider =
    Provider<CoordinatorReportsRemoteDataSource>((ref) {
  return CoordinatorReportsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final coordinatorReportsRepositoryProvider =
    Provider<CoordinatorReportsRepository>((ref) {
  return CoordinatorReportsRepositoryImpl(
    remoteDataSource: ref.read(coordinatorReportsRemoteDataSourceProvider),
  );
});

// ── Compliance ────────────────────────────────────────────────────────────────

/// Compliance filter. All null = the whole active ecclesiastical year.
typedef ComplianceQuery = ({int? year, int? month});

const ComplianceQuery kWholeYearCompliance = (year: null, month: null);

/// Compliance query for one month (null period = whole year).
ComplianceQuery complianceQueryFor(ReportPeriodKey? period) {
  if (period == null) return kWholeYearCompliance;
  return (year: period.year, month: period.index);
}

/// GET /reports/compliance for [ComplianceQuery].
final reportComplianceProvider = FutureProvider.autoDispose
    .family<ReportCompliance, ComplianceQuery>((ref, query) async {
  final repository = ref.read(coordinatorReportsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getCompliance(
    year: query.year,
    month: query.month,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw CoordinatorLoadException.fromFailure(failure),
    (compliance) => compliance,
  );
});

// ── Reports view filters ──────────────────────────────────────────────────────

/// A month of a given calendar year.
typedef ReportPeriodKey = ({int year, int index});

/// Month picked by the user; null = the default month
/// ([ReportCompliance.defaultPeriod]).
final coordinatorReportPeriodProvider =
    StateProvider.autoDispose<ReportPeriodKey?>((ref) => null);

// ── Report lists ──────────────────────────────────────────────────────────────

typedef ReportListQuery = ({int? year, int? period});

/// Every monthly report of one month visible to the coordinator.
final coordinatorReportListProvider = FutureProvider.autoDispose
    .family<List<CoordinatorReport>, ReportListQuery>((ref, query) async {
  final repository = ref.read(coordinatorReportsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.listReports(
    year: query.year,
    period: query.period,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw CoordinatorLoadException.fromFailure(failure),
    (reports) => reports,
  );
});

// ── PDF ───────────────────────────────────────────────────────────────────────

/// Local path of a downloaded monthly report PDF.
final coordinatorReportPdfProvider =
    FutureProvider.autoDispose.family<String, int>((ref, reportId) async {
  final repository = ref.read(coordinatorReportsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.downloadReportPdf(
    reportId: reportId,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw CoordinatorLoadException.fromFailure(failure),
    (path) => path,
  );
});
