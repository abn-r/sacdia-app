import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/keep_alive_during.dart';
import '../../../../core/providers/riverpod_aliases.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../data/datasources/finances_remote_data_source.dart';
import '../../data/repositories/finances_repository_impl.dart';
import '../../domain/entities/category_breakdown.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/finance_month.dart';
import '../../domain/entities/finance_monthly_series.dart';
import '../../domain/entities/finance_summary.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_filter.dart';
import '../../domain/repositories/finances_repository.dart';
import '../../domain/usecases/create_transaction.dart';
import '../../domain/usecases/delete_transaction.dart';
import '../../domain/usecases/export_finances.dart';
import '../../domain/usecases/get_categories.dart';
import '../../domain/usecases/get_category_breakdown.dart';
import '../../domain/usecases/get_finance_monthly_series.dart';
import '../../domain/usecases/get_finance_summary.dart';
import '../../domain/usecases/get_finances.dart';
import '../../domain/usecases/update_transaction.dart';
import '../../domain/usecases/upload_finance_evidence.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────────

final financesRemoteDataSourceProvider =
    Provider<FinancesRemoteDataSource>((ref) {
  return FinancesRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final financesRepositoryProvider = Provider<FinancesRepository>((ref) {
  return FinancesRepositoryImpl(
    remoteDataSource: ref.read(financesRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Use cases ──────────────────────────────────────────────────────────────────

final getFinancesUseCaseProvider = Provider<GetFinances>((ref) {
  return GetFinances(ref.read(financesRepositoryProvider));
});

final getFinanceSummaryUseCaseProvider = Provider<GetFinanceSummary>((ref) {
  return GetFinanceSummary(ref.read(financesRepositoryProvider));
});

final getCategoryBreakdownUseCaseProvider =
    Provider<GetCategoryBreakdown>((ref) {
  return GetCategoryBreakdown(ref.read(financesRepositoryProvider));
});

final getFinanceMonthlySeriesUseCaseProvider =
    Provider<GetFinanceMonthlySeries>((ref) {
  return GetFinanceMonthlySeries(ref.read(financesRepositoryProvider));
});

final exportFinancesUseCaseProvider = Provider<ExportFinances>((ref) {
  return ExportFinances(ref.read(financesRepositoryProvider));
});

final getFinanceCategoriesUseCaseProvider =
    Provider<GetFinanceCategories>((ref) {
  return GetFinanceCategories(ref.read(financesRepositoryProvider));
});

final createTransactionUseCaseProvider = Provider<CreateTransaction>((ref) {
  return CreateTransaction(ref.read(financesRepositoryProvider));
});

final updateTransactionUseCaseProvider = Provider<UpdateTransaction>((ref) {
  return UpdateTransaction(ref.read(financesRepositoryProvider));
});

final deleteTransactionUseCaseProvider = Provider<DeleteTransaction>((ref) {
  return DeleteTransaction(ref.read(financesRepositoryProvider));
});

final uploadFinanceEvidenceUseCaseProvider =
    Provider<UploadFinanceEvidence>((ref) {
  return UploadFinanceEvidence(ref.read(financesRepositoryProvider));
});

// ── Selected month navigation state ───────────────────────────────────────────

class SelectedMonth extends Equatable {
  final int year;
  final int month;

  const SelectedMonth({required this.year, required this.month});

  SelectedMonth previous() {
    final d = DateTime(year, month - 1);
    return SelectedMonth(year: d.year, month: d.month);
  }

  SelectedMonth next() {
    final d = DateTime(year, month + 1);
    return SelectedMonth(year: d.year, month: d.month);
  }

  /// Negativo si [other] es posterior, positivo si es anterior, 0 si igual.
  int compareTo(SelectedMonth other) =>
      (year * 12 + month) - (other.year * 12 + other.month);

  bool get isCurrentMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  @override
  List<Object?> get props => [year, month];
}

class SelectedMonthNotifier extends Notifier<SelectedMonth> {
  @override
  SelectedMonth build() => SelectedMonth(
        year: DateTime.now().year,
        month: DateTime.now().month,
      );

  void goToPrevious() => state = state.previous();

  void goToNext() {
    if (!state.isCurrentMonth) {
      state = state.next();
    }
  }

  /// Vuelve al mes en curso.
  void goToCurrent() {
    final now = DateTime.now();
    state = SelectedMonth(year: now.year, month: now.month);
  }

  void jumpTo(int year, int month) =>
      state = SelectedMonth(year: year, month: month);
}

final selectedMonthProvider =
    NotifierProvider.autoDispose<SelectedMonthNotifier, SelectedMonth>(
  SelectedMonthNotifier.new,
);

/// Period selection for the finance line chart (1M, 3M, 6M, 1A, Todo)
final selectedPeriodProvider = StateProvider.autoDispose<String>((ref) => '1M');

// ── Club ID helper ─────────────────────────────────────────────────────────────

/// Obtiene el clubId desde el contexto del usuario.
final currentClubIdProvider = FutureProvider.autoDispose<int?>((ref) async {
  final context = await ref.watch(clubContextProvider.future);
  return context?.clubId;
});

// ── Per-month cache ────────────────────────────────────────────────────────────

/// Cuánto se conservan los datos de un mes ya visitado cuando nadie lo mira.
const Duration kFinanceCacheTtl = Duration(minutes: 5);

/// Mes de un club: llave de la caché de Finanzas.
class FinanceMonthKey extends Equatable {
  final int clubId;
  final int year;
  final int month;

  const FinanceMonthKey({
    required this.clubId,
    required this.year,
    required this.month,
  });

  FinanceMonthKey get previous {
    final d = DateTime(year, month - 1);
    return FinanceMonthKey(clubId: clubId, year: d.year, month: d.month);
  }

  @override
  List<Object?> get props => [clubId, year, month];
}

/// Suelta el `keepAlive` de [link] [kFinanceCacheTtl] después de que el último
/// oyente se va. El temporizador también corre desde la creación: un mes que se
/// precarga sin oyente nunca dispara `onCancel`.
void _releaseAfterTtl(Ref ref, KeepAliveLink link) {
  Timer? timer;
  void start() {
    timer?.cancel();
    timer = Timer(kFinanceCacheTtl, link.close);
  }

  start();
  ref.onCancel(start);
  ref.onResume(() => timer?.cancel());
  ref.onDispose(() => timer?.cancel());
}

/// Carga [load] con un token que se cancela al descartar la entrada. Un fallo
/// no se cachea: suelta el `keepAlive` para que la siguiente lectura reintente.
Future<T> _loadCachedEntry<T>(
  Ref ref,
  KeepAliveLink link,
  Future<T> Function(CancelToken cancelToken) load,
) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  try {
    return await load(cancelToken);
  } catch (_) {
    link.close();
    rethrow;
  }
}

/// Movimientos de un mes. Se conserva [kFinanceCacheTtl] tras dejar de
/// mirarse, así volver a un mes ya visitado es instantáneo.
///
/// La vista no lo lee directo: usa [financeMonthProvider] (mes seleccionado).
final financeMonthByKeyProvider = FutureProvider.autoDispose
    .family<FinanceMonth?, FinanceMonthKey>((ref, key) async {
  final link = ref.keepAlive();
  _releaseAfterTtl(ref, link);
  final useCase = ref.read(getFinancesUseCaseProvider);

  return _loadCachedEntry(ref, link, (cancelToken) async {
    final result = await useCase(
      GetFinancesParams(
        clubId: key.clubId,
        year: key.year,
        month: key.month,
      ),
      cancelToken: cancelToken,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (month) => month,
    );
  });
});

/// Resumen (saldo acumulado y totales) de un mes. Ver [financeMonthByKeyProvider].
final financeSummaryByKeyProvider = FutureProvider.autoDispose
    .family<FinanceSummary?, FinanceMonthKey>((ref, key) async {
  final link = ref.keepAlive();
  _releaseAfterTtl(ref, link);
  final useCase = ref.read(getFinanceSummaryUseCaseProvider);

  return _loadCachedEntry(ref, link, (cancelToken) async {
    final result = await useCase(
      GetFinanceSummaryParams(
        clubId: key.clubId,
        year: key.year,
        month: key.month,
      ),
      cancelToken: cancelToken,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (summary) => summary,
    );
  });
});

/// Totales por categoría de un mes. Ver [financeMonthByKeyProvider].
final financeByCategoryByKeyProvider = FutureProvider.autoDispose
    .family<CategoryBreakdown?, FinanceMonthKey>((ref, key) async {
  final link = ref.keepAlive();
  _releaseAfterTtl(ref, link);
  final useCase = ref.read(getCategoryBreakdownUseCaseProvider);

  return _loadCachedEntry(ref, link, (cancelToken) async {
    final result = await useCase(
      GetCategoryBreakdownParams(
        clubId: key.clubId,
        year: key.year,
        month: key.month,
      ),
      cancelToken: cancelToken,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (breakdown) => breakdown,
    );
  });
});

/// Serie mensual de un club para un período del gráfico (3M, 6M, 1A o Todo)
/// que termina en [year]/[month]: llave de [financeSeriesByKeyProvider].
class FinanceSeriesKey extends Equatable {
  final int clubId;

  /// '3M', '6M', '1A' o 'Todo'.
  final String period;
  final int year;
  final int month;

  const FinanceSeriesKey({
    required this.clubId,
    required this.period,
    required this.year,
    required this.month,
  });

  /// Cuántos meses abarca el período; `null` = desde el primer movimiento.
  int? get span => switch (period) {
        '3M' => 3,
        '6M' => 6,
        '1A' => 12,
        _ => null,
      };

  /// Primer mes de la serie (`null` = lo decide el servidor).
  ({int year, int month})? get from {
    final n = span;
    if (n == null) return null;
    final d = DateTime(year, month - (n - 1));
    return (year: d.year, month: d.month);
  }

  @override
  List<Object?> get props => [clubId, period, year, month];
}

/// Serie mensual de un período del gráfico. Se conserva [kFinanceCacheTtl] tras
/// dejar de mirarse. La vista usa [financeSeriesProvider].
final financeSeriesByKeyProvider = FutureProvider.autoDispose
    .family<FinanceMonthlySeries?, FinanceSeriesKey>((ref, key) async {
  final link = ref.keepAlive();
  _releaseAfterTtl(ref, link);
  final useCase = ref.read(getFinanceMonthlySeriesUseCaseProvider);

  return _loadCachedEntry(ref, link, (cancelToken) async {
    final from = key.from;
    final result = await useCase(
      GetFinanceMonthlySeriesParams(
        clubId: key.clubId,
        fromYear: from?.year,
        fromMonth: from?.month,
        toYear: key.year,
        toMonth: key.month,
      ),
      cancelToken: cancelToken,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (series) => series,
    );
  });
});

/// Descarta TODA la caché de Finanzas (todos los meses).
///
/// Cualquier cambio (movimiento creado, editado, borrado, evidencia) o un
/// recordatorio del servidor la vacía entera: el saldo acumulado de los meses
/// posteriores también cambia, así que no basta con el mes tocado. Los
/// invocadores pasan su `ref.invalidate`.
void invalidateFinanceData(
  void Function(ProviderOrFamily provider) invalidate,
) {
  invalidate(financeMonthByKeyProvider);
  invalidate(financeSummaryByKeyProvider);
  invalidate(financeByCategoryByKeyProvider);
  invalidate(financeSeriesByKeyProvider);
}

// ── Selected month views (stale-while-loading) ─────────────────────────────────

/// Un dato de Finanzas del mes seleccionado.
///
/// A diferencia de un `AsyncValue`, [value] conserva el del mes anterior
/// mientras el nuevo carga ([isLoading]): la pantalla no se vacía al cambiar
/// de mes, solo se atenúa.
class FinanceSlice<T extends Object> extends Equatable {
  /// Dato actual o, si [isLoading] o [hasError], el último que hubo.
  final T? value;

  /// El mes seleccionado aún no llega (o se está refrescando).
  final bool isLoading;

  final Object? error;
  final StackTrace? stackTrace;

  const FinanceSlice({
    this.value,
    this.isLoading = false,
    this.error,
    this.stackTrace,
  });

  bool get hasError => error != null;

  /// [value] pertenece a otro mes (o hay error): no mostrarlo sin atenuar.
  bool get isStale => isLoading || hasError;

  /// Mismo contrato que `AsyncValue.when`, sin pantalla de carga si ya hubo
  /// un dato que mostrar.
  R when<R>({
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function(T? data) data,
  }) {
    if (hasError) return error(this.error!, stackTrace ?? StackTrace.empty);
    if (isLoading && value == null) return loading();
    return data(value);
  }

  @override
  List<Object?> get props => [value, isLoading, error];
}

/// Lee un dato por mes de la caché y lo expone para el mes seleccionado,
/// recordando el último dato bueno entre cambios de mes.
abstract class _SelectedFinanceNotifier<T extends Object>
    extends Notifier<FinanceSlice<T>> {
  T? _lastGood;

  AsyncValue<T?> watchEntry(FinanceMonthKey key);

  @override
  FinanceSlice<T> build() {
    final clubAsync = ref.watch(currentClubIdProvider);
    if (!clubAsync.hasValue) {
      if (clubAsync.hasError) {
        return FinanceSlice<T>(
          value: _lastGood,
          error: clubAsync.error,
          stackTrace: clubAsync.stackTrace,
        );
      }
      return FinanceSlice<T>(value: _lastGood, isLoading: true);
    }
    final clubId = clubAsync.value;
    if (clubId == null) return const FinanceSlice();

    final selected = ref.watch(selectedMonthProvider);
    final entry = watchEntry(
      FinanceMonthKey(
        clubId: clubId,
        year: selected.year,
        month: selected.month,
      ),
    );

    if (entry.hasError) {
      return FinanceSlice<T>(
        value: _lastGood,
        error: entry.error,
        stackTrace: entry.stackTrace,
      );
    }
    if (entry.isLoading) {
      return FinanceSlice<T>(value: entry.value ?? _lastGood, isLoading: true);
    }
    final value = entry.value;
    if (value != null) _lastGood = value;
    return FinanceSlice<T>(value: value);
  }
}

class SelectedFinanceMonthNotifier
    extends _SelectedFinanceNotifier<FinanceMonth> {
  @override
  AsyncValue<FinanceMonth?> watchEntry(FinanceMonthKey key) =>
      ref.watch(financeMonthByKeyProvider(key));
}

class SelectedFinanceSummaryNotifier
    extends _SelectedFinanceNotifier<FinanceSummary> {
  @override
  AsyncValue<FinanceSummary?> watchEntry(FinanceMonthKey key) =>
      ref.watch(financeSummaryByKeyProvider(key));
}

class SelectedFinanceByCategoryNotifier
    extends _SelectedFinanceNotifier<CategoryBreakdown> {
  @override
  AsyncValue<CategoryBreakdown?> watchEntry(FinanceMonthKey key) =>
      ref.watch(financeByCategoryByKeyProvider(key));
}

/// Serie mensual del período del gráfico (3M/6M/1A/Todo) que termina en el
/// mes seleccionado. Con '1M' no pide nada: el gráfico usa los movimientos.
class SelectedFinanceSeriesNotifier
    extends _SelectedFinanceNotifier<FinanceMonthlySeries> {
  @override
  AsyncValue<FinanceMonthlySeries?> watchEntry(FinanceMonthKey key) {
    final period = ref.watch(selectedPeriodProvider);
    if (period == '1M') return const AsyncData(null);
    return ref.watch(
      financeSeriesByKeyProvider(
        FinanceSeriesKey(
          clubId: key.clubId,
          period: period,
          year: key.year,
          month: key.month,
        ),
      ),
    );
  }
}

/// Movimientos del mes seleccionado.
final financeMonthProvider = NotifierProvider.autoDispose<
    SelectedFinanceMonthNotifier, FinanceSlice<FinanceMonth>>(
  SelectedFinanceMonthNotifier.new,
);

/// Resumen del mes seleccionado.
final financeSummaryProvider = NotifierProvider.autoDispose<
    SelectedFinanceSummaryNotifier, FinanceSlice<FinanceSummary>>(
  SelectedFinanceSummaryNotifier.new,
);

/// Totales por categoría del mes seleccionado.
final financeByCategoryProvider = NotifierProvider.autoDispose<
    SelectedFinanceByCategoryNotifier, FinanceSlice<CategoryBreakdown>>(
  SelectedFinanceByCategoryNotifier.new,
);

/// Serie mensual del período seleccionado (ver [SelectedFinanceSeriesNotifier]).
final financeSeriesProvider = NotifierProvider.autoDispose<
    SelectedFinanceSeriesNotifier, FinanceSlice<FinanceMonthlySeries>>(
  SelectedFinanceSeriesNotifier.new,
);

/// Precarga el mes anterior cuando el seleccionado ya cargó, para que «atrás»
/// sea instantáneo. La vista lo observa; no expone nada.
final financePrefetchProvider = Provider.autoDispose<void>((ref) {
  final clubId = ref.watch(currentClubIdProvider).value;
  final selected = ref.watch(selectedMonthProvider);
  final month = ref.watch(financeMonthProvider);
  final summary = ref.watch(financeSummaryProvider);
  if (clubId == null || month.isStale || summary.isStale) return;

  final previous = FinanceMonthKey(
    clubId: clubId,
    year: selected.year,
    month: selected.month,
  ).previous;
  ref.read(financeMonthByKeyProvider(previous).future).ignore();
  ref.read(financeSummaryByKeyProvider(previous).future).ignore();
  ref.read(financeByCategoryByKeyProvider(previous).future).ignore();
});

// ── Closed period ──────────────────────────────────────────────────────────────

/// ¿El mes seleccionado está cerrado?
///
/// El resumen manda `period_closed` y es la fuente principal; mientras no
/// llega (o si falla) se usa la marca de los movimientos del mes.
final financePeriodClosedProvider = Provider.autoDispose<bool>((ref) {
  final summaryClosed = ref.watch(financeSummaryProvider).value?.periodClosed;
  if (summaryClosed != null) return summaryClosed;
  final isOpen = ref.watch(financeMonthProvider).value?.isOpen ?? true;
  return !isOpen;
});

// ── Finance categories provider ────────────────────────────────────────────────

final financeCategoriesProvider =
    FutureProvider.autoDispose<List<FinanceCategory>>((ref) async {
  final useCase = ref.read(getFinanceCategoriesUseCaseProvider);

  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final result = await useCase(cancelToken: cancelToken);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (cats) => cats,
  );
});

// ── Permission helper ──────────────────────────────────────────────────────────

/// Devuelve true si el usuario puede gestionar transacciones.
/// Usa selectAsync para evitar rebuilds por cambios no relacionados al objeto UserEntity.
final canManageFinancesProvider = FutureProvider.autoDispose<bool>((ref) async {
  final authState = await ref.watch(
    authNotifierProvider.selectAsync((u) => u),
  );
  if (authState == null) return false;

  return hasAnyPermission(authState, const {
    'finances:create',
    'finances:update',
    'finances:delete',
  });
});

// ── Transaction operation state ────────────────────────────────────────────────

class TransactionFormState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;
  final FinanceTransaction? savedTransaction;

  const TransactionFormState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
    this.savedTransaction,
  });

  TransactionFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
    FinanceTransaction? savedTransaction,
    bool clearSavedTransaction = false,
  }) {
    return TransactionFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
      savedTransaction: clearSavedTransaction
          ? null
          : savedTransaction ?? this.savedTransaction,
    );
  }
}

class TransactionFormNotifier extends Notifier<TransactionFormState> {
  @override
  TransactionFormState build() => const TransactionFormState();

  /// Maps the human-readable club type name (from ClubContext) to the integer
  /// id expected by the backend CreateFinanceDto.
  int _clubTypeIdFromName(String? name) {
    switch (name?.toLowerCase().trim()) {
      case 'aventureros':
        return 1;
      case 'conquistadores':
        return 2;
      case 'guías mayores':
      case 'guias mayores':
        return 3;
      default:
        return 2; // fallback to Conquistadores
    }
  }

  Future<bool> save({
    required int clubId,
    required int categoryId,
    required double amount,
    required String description,
    required DateTime date,
    required int year,
    required int month,
    int? existingId, // non-null → update
  }) =>
      // Callers only `ref.read` this notifier: keep it alive until the request
      // settles (see keepAliveDuring).
      ref.keepAliveDuring(() async {
        state = state.copyWith(
          isLoading: true,
          errorMessage: null,
          success: false,
          clearSavedTransaction: true,
        );

        if (existingId != null) {
          // Update — backend only accepts amount, description, finance_category_id,
          // finance_date, post_closing_note. No notes field.
          final result = await ref.read(updateTransactionUseCaseProvider)(
            UpdateTransactionParams(
              financeId: existingId,
              categoryId: categoryId,
              amount: amount,
              description: description,
            ),
          );

          return result.fold<bool>(
            (failure) {
              state = state.copyWith(
                  isLoading: false, errorMessage: failure.message);
              return false;
            },
            (transaction) {
              state = state.copyWith(
                isLoading: false,
                success: true,
                savedTransaction: transaction,
              );
              invalidateFinanceData(ref.invalidate);
              ref.invalidate(transactionDetailProvider(existingId));
              return true;
            },
          );
        } else {
          // Create — resolve club_section_id and club_type_id from ClubContext.
          final clubContext = await ref.read(clubContextProvider.future);
          final clubSectionId = clubContext?.sectionId ?? 0;
          final clubTypeId = _clubTypeIdFromName(clubContext?.clubTypeName);

          final result = await ref.read(createTransactionUseCaseProvider)(
            CreateTransactionParams(
              clubId: clubId,
              categoryId: categoryId,
              amount: amount,
              description: description,
              date: date,
              year: year,
              month: month,
              clubSectionId: clubSectionId,
              clubTypeId: clubTypeId,
            ),
          );

          return result.fold<bool>(
            (failure) {
              state = state.copyWith(
                  isLoading: false, errorMessage: failure.message);
              return false;
            },
            (transaction) {
              state = state.copyWith(
                isLoading: false,
                success: true,
                savedTransaction: transaction,
              );
              invalidateFinanceData(ref.invalidate);
              return true;
            },
          );
        }
      });

  Future<bool> delete({required int financeId}) =>
      ref.keepAliveDuring(() async {
        state = state.copyWith(
          isLoading: true,
          errorMessage: null,
          success: false,
          clearSavedTransaction: true,
        );

        final result = await ref.read(deleteTransactionUseCaseProvider)(
          financeId: financeId,
        );

        return result.fold<bool>(
          (failure) {
            state =
                state.copyWith(isLoading: false, errorMessage: failure.message);
            return false;
          },
          (_) {
            state = state.copyWith(isLoading: false, success: true);
            invalidateFinanceData(ref.invalidate);
            ref.invalidate(transactionDetailProvider(financeId));
            return true;
          },
        );
      });

  Future<bool> uploadEvidence({
    required int financeId,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) =>
      ref.keepAliveDuring(() async {
        state = state.copyWith(
          isLoading: true,
          errorMessage: null,
          success: false,
        );

        final result = await ref.read(uploadFinanceEvidenceUseCaseProvider)(
          UploadFinanceEvidenceParams(
            financeId: financeId,
            filePath: filePath,
            fileName: fileName,
            mimeType: mimeType,
          ),
        );

        return result.fold<bool>(
          (failure) {
            state = state.copyWith(
              isLoading: false,
              errorMessage: failure.message,
              success: false,
            );
            return false;
          },
          (_) {
            state = state.copyWith(isLoading: false, success: true);
            invalidateFinanceData(ref.invalidate);
            ref.invalidate(transactionDetailProvider(financeId));
            return true;
          },
        );
      });

  void reset() => state = const TransactionFormState();
}

final transactionFormNotifierProvider =
    NotifierProvider.autoDispose<TransactionFormNotifier, TransactionFormState>(
  TransactionFormNotifier.new,
);

// ── Transaction detail by id ───────────────────────────────────────────────────

/// Carga un movimiento individual — usado en la pantalla de detalle.
final transactionDetailProvider =
    FutureProvider.autoDispose.family<FinanceTransaction, int>((ref, id) async {
  final repo = ref.read(financesRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repo.getTransaction(
    financeId: id,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (t) => t,
  );
});

// ── All Transactions — filter state ───────────────────────────────────────────

/// Accumulated state for the All Transactions screen.
class AllTransactionsState {
  /// All transactions accumulated so far (across pages already loaded).
  final List<FinanceTransaction> transactions;

  /// Active filter configuration.
  final TransactionFilter filter;

  /// Current page (1-indexed). Incremented after each successful load.
  final int currentPage;

  /// Whether the server has more pages after the current one.
  final bool hasNextPage;

  /// Whether a page fetch is in progress (used for the load-more indicator).
  final bool isLoadingMore;

  /// Whether the first-page fetch is in progress (full loading state).
  final bool isLoading;

  /// Non-null when a network error occurred.
  final String? errorMessage;

  const AllTransactionsState({
    this.transactions = const [],
    this.filter = const TransactionFilter(),
    this.currentPage = 1,
    this.hasNextPage = false,
    this.isLoadingMore = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AllTransactionsState copyWith({
    List<FinanceTransaction>? transactions,
    TransactionFilter? filter,
    int? currentPage,
    bool? hasNextPage,
    bool? isLoadingMore,
    bool? isLoading,
    Object? errorMessage = _sentinel,
  }) {
    return AllTransactionsState(
      transactions: transactions ?? this.transactions,
      filter: filter ?? this.filter,
      currentPage: currentPage ?? this.currentPage,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _sentinel = Object();

/// Manages filter + pagination state for the All Transactions screen.
///
/// All filter changes reset to page 1 and clear the accumulated list before
/// triggering a fresh fetch.
class AllTransactionsFilterNotifier extends Notifier<AllTransactionsState> {
  @override
  AllTransactionsState build() => const AllTransactionsState();

  // ── Initialisation ──────────────────────────────────────────────────────

  /// Initialises the filter with the month from [FinancesView] and fetches
  /// page 1.  Call this after the first frame via [WidgetsBinding.addPostFrameCallback].
  void initWithMonth(SelectedMonth month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0); // last day

    state = AllTransactionsState(
      filter: TransactionFilter(
        rangePreset: DateRangePreset.thisMonth,
        startDate: start,
        endDate: end,
      ),
      isLoading: true,
    );

    _fetchPage(1, replace: true);
  }

  // ── Filter mutations ────────────────────────────────────────────────────

  void updateSearch(String search) {
    final trimmed = search.trim().isEmpty ? null : search.trim();
    _resetAndFetch(
      state.filter.copyWith(search: trimmed ?? ''),
    );
  }

  void updateType(TransactionType? type) {
    _resetAndFetch(state.filter.copyWith(type: type));
  }

  void updateSort({required String sortBy, required String sortOrder}) {
    _resetAndFetch(state.filter.copyWith(sortBy: sortBy, sortOrder: sortOrder));
  }

  void updateRange({
    required DateRangePreset preset,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (preset) {
      case DateRangePreset.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0);
      case DateRangePreset.last3Months:
        start = DateTime(now.year, now.month - 2, 1);
        end = now;
      case DateRangePreset.lastYear:
        start = DateTime(now.year - 1, now.month, now.day);
        end = now;
      case DateRangePreset.custom:
        start = startDate;
        end = endDate;
    }

    _resetAndFetch(
      state.filter.copyWith(
        rangePreset: preset,
        startDate: start,
        endDate: end,
      ),
    );
  }

  // ── Pagination ──────────────────────────────────────────────────────────

  /// Load the next page (called from scroll listener).
  void loadNextPage() {
    if (!state.hasNextPage || state.isLoadingMore) return;
    _fetchPage(state.currentPage + 1, replace: false);
  }

  /// Pull-to-refresh: restart from page 1.
  void reset() {
    state = state.copyWith(
      transactions: [],
      currentPage: 1,
      hasNextPage: false,
      isLoading: true,
      errorMessage: null,
    );
    _fetchPage(1, replace: true);
  }

  // ── Internal helpers ────────────────────────────────────────────────────

  void _resetAndFetch(TransactionFilter newFilter) {
    state = AllTransactionsState(
      filter: newFilter,
      isLoading: true,
    );
    _fetchPage(1, replace: true);
  }

  Future<void> _fetchPage(int page, {required bool replace}) async {
    if (page == 1) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    } else {
      state = state.copyWith(isLoadingMore: true, errorMessage: null);
    }

    final clubId = await ref.read(currentClubIdProvider.future);
    if (clubId == null) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: 'finances.providers.club_unavailable'.tr(),
      );
      return;
    }

    final filter = state.filter;
    final repo = ref.read(financesRepositoryProvider);

    final result = await repo.getTransactionsPaginated(
      clubId: clubId,
      page: page,
      limit: 20,
      type: _typeParam(filter.type),
      search: filter.search,
      startDate: _dateParam(filter.startDate),
      endDate: _dateParam(filter.endDate),
      sortBy: filter.sortBy,
      sortOrder: filter.sortOrder,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          errorMessage: failure.message,
        );
      },
      (response) {
        final newList =
            replace ? response.data : [...state.transactions, ...response.data];
        state = state.copyWith(
          transactions: newList,
          currentPage: response.meta.page,
          hasNextPage: response.meta.hasNextPage,
          isLoading: false,
          isLoadingMore: false,
          errorMessage: null,
        );
      },
    );
  }

  static String? _typeParam(TransactionType? type) {
    if (type == null) return null;
    return type.isIncome ? 'income' : 'expense';
  }

  static String? _dateParam(DateTime? date) {
    if (date == null) return null;
    return DateFormat('yyyy-MM-dd').format(date);
  }
}

final allTransactionsFilterNotifierProvider = NotifierProvider.autoDispose<
    AllTransactionsFilterNotifier, AllTransactionsState>(
  AllTransactionsFilterNotifier.new,
);

/// Computed label for the AppBar subtitle based on the active range.
final allTransactionsRangeLabelProvider = Provider.autoDispose<String>((ref) {
  final filter =
      ref.watch(allTransactionsFilterNotifierProvider.select((s) => s.filter));
  return _rangeLabelFromFilter(filter);
});

String _rangeLabelFromFilter(TransactionFilter filter) {
  switch (filter.rangePreset) {
    case DateRangePreset.last3Months:
      return 'finances.widgets.range_last_3_months'.tr();
    case DateRangePreset.lastYear:
      return 'finances.widgets.range_last_year'.tr();
    case DateRangePreset.custom:
      if (filter.startDate != null && filter.endDate != null) {
        final fmt = DateFormat('d MMM');
        final yearFmt = DateFormat('yyyy');
        return '${fmt.format(filter.startDate!)} – '
            '${fmt.format(filter.endDate!)} ${yearFmt.format(filter.endDate!)}';
      }
      return 'finances.widgets.range_custom_label'.tr();
    case DateRangePreset.thisMonth:
      if (filter.startDate != null) {
        final label = DateFormat('MMMM yyyy').format(filter.startDate!);
        return label[0].toUpperCase() + label.substring(1);
      }
      final now = DateTime.now();
      final label = DateFormat('MMMM yyyy').format(now);
      return label[0].toUpperCase() + label.substring(1);
  }
}
