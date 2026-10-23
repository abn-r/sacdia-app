import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
typedef ComplianceQuery = ({int? year, int? month, int? quarter});

const ComplianceQuery kWholeYearCompliance =
    (year: null, month: null, quarter: null);

/// Compliance query for one period of [kind] (null period = whole year).
ComplianceQuery complianceQueryFor(
  CoordinatorReportKind kind,
  ReportPeriodKey? period,
) {
  if (period == null || !kind.hasPeriods) return kWholeYearCompliance;
  return (
    year: period.year,
    month: kind == CoordinatorReportKind.monthly ? period.index : null,
    quarter: kind == CoordinatorReportKind.quarterly ? period.index : null,
  );
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
    quarter: query.quarter,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw CoordinatorLoadException.fromFailure(failure),
    (compliance) => compliance,
  );
});

// ── Reports view filters ──────────────────────────────────────────────────────

/// Report kind selected in the reports view.
final coordinatorReportKindProvider =
    StateProvider.autoDispose<CoordinatorReportKind>(
  (ref) => CoordinatorReportKind.monthly,
);

/// A month or quarter of a given calendar year.
typedef ReportPeriodKey = ({int year, int index});

/// Period picked by the user; null = the default period of the kind
/// ([ReportCompliance.defaultPeriodFor]).
final coordinatorReportPeriodProvider =
    StateProvider.autoDispose<ReportPeriodKey?>((ref) => null);

// ── Report lists ──────────────────────────────────────────────────────────────

typedef ReportListQuery = ({
  CoordinatorReportKind kind,
  int? year,
  int? period,
  int? ecclesiasticalYearId,
});

/// Every report of one kind and period visible to the coordinator.
final coordinatorReportListProvider = FutureProvider.autoDispose
    .family<List<CoordinatorReport>, ReportListQuery>((ref, query) async {
  final repository = ref.read(coordinatorReportsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.listReports(
    kind: query.kind,
    year: query.year,
    period: query.period,
    ecclesiasticalYearId: query.ecclesiasticalYearId,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw CoordinatorLoadException.fromFailure(failure),
    (reports) => reports,
  );
});

// ── PDF ───────────────────────────────────────────────────────────────────────

typedef ReportPdfKey = ({CoordinatorReportKind kind, int id});

/// Local path of a downloaded report PDF.
final coordinatorReportPdfProvider =
    FutureProvider.autoDispose.family<String, ReportPdfKey>((ref, key) async {
  final repository = ref.read(coordinatorReportsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.downloadReportPdf(
    kind: key.kind,
    reportId: key.id,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw CoordinatorLoadException.fromFailure(failure),
    (path) => path,
  );
});
