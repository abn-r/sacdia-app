import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/keep_alive_during.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_pending.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_pending_provider.dart';
import 'package:sacdia_app/features/enrollment/domain/entities/enrollment.dart';
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

  final Enrollment? enrollment;
  try {
    enrollment = await ref.watch(currentEnrollmentProvider.future);
  } on Failure {
    return const [];
  }
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

/// Día del mes siguiente en que el sistema genera el informe
/// (`reports.auto_generate_day` del servidor). Mismo valor que usa el backend
/// si la configuración falta o es inválida.
const int kMonthlyReportDefaultDueDay = 5;

/// Día de generación automática. La app no tiene un endpoint de configuración:
/// lo lee de la fecha límite que el servidor ya manda en los pendientes del
/// inicio (`GET /dashboard/pending`, fila del informe mensual). Sin esa fila
/// (informe ya enviado, sin permiso de enviar o sin red) usa
/// [kMonthlyReportDefaultDueDay].
final monthlyReportDueDayProvider = Provider.autoDispose<int>((ref) {
  final pending = ref.watch(dashboardPendingProvider).value;
  for (final item in pending?.items ?? const <PendingItem>[]) {
    if (item.type != PendingItemType.monthlyReport) continue;
    final due = item.dueDate;
    if (due == null) continue;
    final day = due.toUtc().day;
    if (day >= 1 && day <= 28) return day;
  }
  return kMonthlyReportDefaultDueDay;
});

/// Mes del que se quiere el valor anterior: enrollment, mes y año del informe
/// que se está llenando.
typedef MonthlyReportPeriodKey = ({String enrollmentId, int month, int year});

/// Datos manuales del mes anterior al informe dado, o `null` si no existe,
/// no tiene datos o la lista no cargó. Sale de la lista por inscripción (ya
/// trae los datos manuales de cada informe), sin pedir nada nuevo al servidor.
final monthlyReportPreviousManualDataProvider = FutureProvider.autoDispose
    .family<MonthlyReportManualData?, MonthlyReportPeriodKey>((ref, key) async {
  final previousMonth = key.month == 1 ? 12 : key.month - 1;
  final previousYear = key.month == 1 ? key.year - 1 : key.year;
  try {
    final reports = await ref
        .watch(monthlyReportsByEnrollmentProvider(key.enrollmentId).future);
    for (final report in reports) {
      if (report.month == previousMonth && report.year == previousYear) {
        return report.manualData;
      }
    }
  } catch (_) {
    // La pista es opcional: sin lista, el formulario no la muestra.
  }
  return null;
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
    return result.fold<String>(
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
    extends Notifier<MonthlyReportMutationState> {
  @override
  MonthlyReportMutationState build() => const MonthlyReportMutationState();

  Future<MonthlyReport?> getOrCreateDraft(MonthlyReportDraftParams params) =>
      ref.keepAliveDuring(() async {
        state = state.copyWith(isLoading: true, clearError: true);
        final repo = ref.read(monthlyReportsRepositoryProvider);
        final result = await repo.getOrCreateDraft(
          params.enrollmentId,
          month: params.month,
          year: params.year,
        );

        return result.fold(
          (failure) {
            state =
                state.copyWith(isLoading: false, errorMessage: failure.message);
            return null;
          },
          (report) {
            state = state.copyWith(isLoading: false, report: report);
            ref.invalidate(visibleMonthlyReportsProvider);
            ref.invalidate(monthlyReportsByEnrollmentProvider);
            return report;
          },
        );
      });

  /// Guarda los datos manuales. [refresh] false (autoguardado del formulario)
  /// no invalida el detalle ni las listas: quien abrió el formulario lo hace
  /// una sola vez al cerrarlo.
  Future<bool> saveManualData(
    String reportId,
    MonthlyReportManualData manualData, {
    bool refresh = true,
  }) =>
      ref.keepAliveDuring(() async {
        state = state.copyWith(isLoading: true, clearError: true);
        final repo = ref.read(monthlyReportsRepositoryProvider);
        final result = await repo.updateManualData(reportId, manualData);

        return result.fold(
          (failure) {
            state =
                state.copyWith(isLoading: false, errorMessage: failure.message);
            return false;
          },
          (report) {
            state = state.copyWith(isLoading: false, report: report);
            if (refresh) {
              ref.invalidate(monthlyReportDetailProvider(reportId));
              ref.invalidate(visibleMonthlyReportsProvider);
              ref.invalidate(monthlyReportsByEnrollmentProvider);
            }
            return true;
          },
        );
      });

  /// Envía el informe generado al campo local.
  Future<bool> submit(String reportId) => ref.keepAliveDuring(() async {
        state = state.copyWith(isLoading: true, clearError: true);
        final repo = ref.read(monthlyReportsRepositoryProvider);
        final result = await repo.submitReport(reportId);

        return result.fold(
          (failure) {
            state =
                state.copyWith(isLoading: false, errorMessage: failure.message);
            return false;
          },
          (report) {
            state = state.copyWith(isLoading: false, report: report);
            ref.invalidate(monthlyReportDetailProvider(reportId));
            ref.invalidate(visibleMonthlyReportsProvider);
            ref.invalidate(monthlyReportsByEnrollmentProvider);
            ref.invalidate(dashboardPendingProvider);
            return true;
          },
        );
      });
}
