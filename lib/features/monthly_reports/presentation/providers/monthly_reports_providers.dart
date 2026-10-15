import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../enrollment/presentation/providers/enrollment_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
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
  final String enrollmentId;
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
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repo = ref.read(monthlyReportsRepositoryProvider);
  final result = await repo.getPreview(
    params.enrollmentId,
    month: params.month,
    year: params.year,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (preview) => preview,
  );
});

/// Lista de informes mensuales de un enrollment.
final monthlyReportsByEnrollmentProvider = FutureProvider.autoDispose
    .family<List<MonthlyReport>, String>((ref, enrollmentId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repo = ref.read(monthlyReportsRepositoryProvider);
  final result =
      await repo.getReportsByEnrollment(enrollmentId, cancelToken: cancelToken);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (reports) => reports,
  );
});

/// Detalle de un informe mensual.
final monthlyReportDetailProvider = FutureProvider.autoDispose
    .family<MonthlyReport, String>((ref, reportId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repo = ref.read(monthlyReportsRepositoryProvider);
  final result = await repo.getReportDetail(reportId, cancelToken: cancelToken);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (report) => report,
  );
});

/// Reportes visibles para el usuario autenticado según su jerarquía/rol.
final visibleMonthlyReportsProvider =
    FutureProvider.autoDispose<VisibleMonthlyReportsPage>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repo = ref.read(monthlyReportsRepositoryProvider);
  final result = await repo.getVisibleReports(cancelToken: cancelToken);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (page) => page,
  );
});

/// Historial de la pantalla Informes.
///
/// Con contexto de club (director, secretario…) son los informes de la
/// inscripción de la sección activa, la misma que usa "Preparar informe".
/// `admin/list` es multi-club: a un director que además coordina le traería
/// informes de otras secciones. Solo sin contexto de club (coordinador o
/// admin) se usa esa lista.
final monthlyReportsHistoryProvider =
    FutureProvider.autoDispose<List<VisibleMonthlyReport>>((ref) async {
  final clubContext = await ref.watch(clubContextProvider.future);
  if (clubContext == null) {
    final page = await ref.watch(visibleMonthlyReportsProvider.future);
    return page.items;
  }

  final enrollment = await ref.watch(currentEnrollmentProvider.future);
  final enrollmentId = enrollment?.endpointId;
  if (enrollmentId == null || enrollmentId == '0') return const [];

  final reports =
      await ref.watch(monthlyReportsByEnrollmentProvider(enrollmentId).future);
  return reports.map(VisibleMonthlyReport.fromReport).toList()
    ..sort((a, b) {
      final byYear = b.year.compareTo(a.year);
      return byYear != 0 ? byYear : b.month.compareTo(a.month);
    });
});

/// Descarga el PDF de un informe mensual y devuelve la ruta local del archivo
/// temporal. El token JWT se envía en el header Authorization — nunca en la URL.
final monthlyReportPdfProvider =
    FutureProvider.autoDispose.family<String, String>((ref, reportId) async {
  // This provider is triggered imperatively from button taps via
  // `ref.read(provider.future)`, not watched by the widget tree. Without a
  // temporary keepAlive, Riverpod may auto-dispose it on the next frame and
  // cancel the in-flight Dio download before the PDF is saved.
  final keepAlive = ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  try {
    final repo = ref.read(monthlyReportsRepositoryProvider);
    final result =
        await repo.downloadReportPdf(reportId, cancelToken: cancelToken);
    return result.fold(
      (failure) => throw Exception(failure.message),
      (localPath) => localPath,
    );
  } finally {
    keepAlive.close();
  }
});

// ── Mutation params/state ────────────────────────────────────────────────────

class MonthlyReportDraftParams {
  final String enrollmentId;
  final int month;
  final int year;

  const MonthlyReportDraftParams({
    required this.enrollmentId,
    required this.month,
    required this.year,
  });
}

class MonthlyReportMutationState {
  final bool isLoading;
  final MonthlyReport? report;
  final String? errorMessage;

  const MonthlyReportMutationState({
    this.isLoading = false,
    this.report,
    this.errorMessage,
  });

  MonthlyReportMutationState copyWith({
    bool? isLoading,
    MonthlyReport? report,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MonthlyReportMutationState(
      isLoading: isLoading ?? this.isLoading,
      report: report ?? this.report,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final monthlyReportMutationProvider = NotifierProvider.autoDispose<
    MonthlyReportMutationNotifier, MonthlyReportMutationState>(
  MonthlyReportMutationNotifier.new,
);

class MonthlyReportMutationNotifier
    extends AutoDisposeNotifier<MonthlyReportMutationState> {
  @override
  MonthlyReportMutationState build() => const MonthlyReportMutationState();

  Future<MonthlyReport?> getOrCreateDraft(
      MonthlyReportDraftParams params) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final repo = ref.read(monthlyReportsRepositoryProvider);
    final result = await repo.getOrCreateDraft(
      params.enrollmentId,
      month: params.month,
      year: params.year,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return null;
      },
      (report) {
        state = state.copyWith(isLoading: false, report: report);
        ref.invalidate(visibleMonthlyReportsProvider);
        ref.invalidate(monthlyReportsByEnrollmentProvider);
        return report;
      },
    );
  }

  Future<bool> saveManualData(
    String reportId,
    MonthlyReportManualData manualData,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final repo = ref.read(monthlyReportsRepositoryProvider);
    final result = await repo.updateManualData(reportId, manualData);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (report) {
        state = state.copyWith(isLoading: false, report: report);
        ref.invalidate(monthlyReportDetailProvider(reportId));
        ref.invalidate(visibleMonthlyReportsProvider);
        ref.invalidate(monthlyReportsByEnrollmentProvider);
        return true;
      },
    );
  }
}
