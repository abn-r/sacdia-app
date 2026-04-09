import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../data/datasources/finances_remote_data_source.dart';
import '../../data/repositories/finances_repository_impl.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/finance_month.dart';
import '../../domain/entities/finance_summary.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_filter.dart';
import '../../domain/repositories/finances_repository.dart';
import '../../domain/usecases/create_transaction.dart';
import '../../domain/usecases/delete_transaction.dart';
import '../../domain/usecases/get_categories.dart';
import '../../domain/usecases/get_finance_summary.dart';
import '../../domain/usecases/get_finances.dart';
import '../../domain/usecases/update_transaction.dart';

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

  bool get isCurrentMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  @override
  List<Object?> get props => [year, month];
}

class SelectedMonthNotifier extends AutoDisposeNotifier<SelectedMonth> {
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

// ── Finance month data provider ────────────────────────────────────────────────

/// Carga los movimientos del mes seleccionado.
final financeMonthProvider =
    FutureProvider.autoDispose<FinanceMonth?>((ref) async {
  final clubIdAsync = await ref.watch(currentClubIdProvider.future);
  if (clubIdAsync == null) return null;

  final selected = ref.watch(selectedMonthProvider);
  final useCase = ref.read(getFinancesUseCaseProvider);

  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final result = await useCase(
    GetFinancesParams(
      clubId: clubIdAsync,
      year: selected.year,
      month: selected.month,
    ),
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (month) => month,
  );
});

// ── Finance summary provider ───────────────────────────────────────────────────

final financeSummaryProvider =
    FutureProvider.autoDispose<FinanceSummary?>((ref) async {
  final clubId = await ref.watch(currentClubIdProvider.future);
  if (clubId == null) return null;

  final useCase = ref.read(getFinanceSummaryUseCaseProvider);

  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final result = await useCase(
    GetFinanceSummaryParams(clubId: clubId),
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
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

/// Roles autorizados para crear/editar movimientos financieros.
const _financeEditorRoles = {
  'director',
  'subdirector',
  'treasurer',
  'tesorero'
};

/// Devuelve true si el usuario puede gestionar transacciones.
/// Usa selectAsync para evitar rebuilds por cambios no relacionados al objeto UserEntity.
final canManageFinancesProvider = FutureProvider.autoDispose<bool>((ref) async {
  final authState = await ref.watch(
    authNotifierProvider.selectAsync((u) => u),
  );
  if (authState == null) return false;

  return canByPermissionOrLegacyRole(
    authState,
    requiredPermissions: const {
      'finances:create',
      'finances:update',
      'finances:delete',
    },
    legacyRoles: _financeEditorRoles,
  );
});

// ── Transaction operation state ────────────────────────────────────────────────

class TransactionFormState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const TransactionFormState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  TransactionFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return TransactionFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

class TransactionFormNotifier extends AutoDisposeNotifier<TransactionFormState> {
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
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

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

      return result.fold(
        (failure) {
          state =
              state.copyWith(isLoading: false, errorMessage: failure.message);
          return false;
        },
        (_) {
          state = state.copyWith(isLoading: false, success: true);
          ref.invalidate(financeMonthProvider);
          ref.invalidate(financeSummaryProvider);
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

      return result.fold(
        (failure) {
          state =
              state.copyWith(isLoading: false, errorMessage: failure.message);
          return false;
        },
        (_) {
          state = state.copyWith(isLoading: false, success: true);
          ref.invalidate(financeMonthProvider);
          ref.invalidate(financeSummaryProvider);
          return true;
        },
      );
    }
  }

  Future<bool> delete({required int financeId}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref.read(deleteTransactionUseCaseProvider)(
      financeId: financeId,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(financeMonthProvider);
        ref.invalidate(financeSummaryProvider);
        return true;
      },
    );
  }

  void reset() => state = const TransactionFormState();
}

final transactionFormNotifierProvider = NotifierProvider.autoDispose<
    TransactionFormNotifier, TransactionFormState>(
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
class AllTransactionsFilterNotifier
    extends AutoDisposeNotifier<AllTransactionsState> {
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
    _resetAndFetch(
        state.filter.copyWith(sortBy: sortBy, sortOrder: sortOrder));
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
        errorMessage: 'Club no disponible',
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
        final newList = replace
            ? response.data
            : [...state.transactions, ...response.data];
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
final allTransactionsRangeLabelProvider =
    Provider.autoDispose<String>((ref) {
  final filter =
      ref.watch(allTransactionsFilterNotifierProvider.select((s) => s.filter));
  return _rangeLabelFromFilter(filter);
});

String _rangeLabelFromFilter(TransactionFilter filter) {
  switch (filter.rangePreset) {
    case DateRangePreset.last3Months:
      return 'Últimos 3 meses';
    case DateRangePreset.lastYear:
      return 'Último año';
    case DateRangePreset.custom:
      if (filter.startDate != null && filter.endDate != null) {
        final fmt = DateFormat('d MMM', 'es');
        final yearFmt = DateFormat('yyyy');
        return '${fmt.format(filter.startDate!)} – '
            '${fmt.format(filter.endDate!)} ${yearFmt.format(filter.endDate!)}';
      }
      return 'Personalizado';
    case DateRangePreset.thisMonth:
      if (filter.startDate != null) {
        final label =
            DateFormat('MMMM yyyy', 'es').format(filter.startDate!);
        return label[0].toUpperCase() + label.substring(1);
      }
      final now = DateTime.now();
      final label = DateFormat('MMMM yyyy', 'es').format(now);
      return label[0].toUpperCase() + label.substring(1);
  }
}
