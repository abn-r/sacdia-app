import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  final result = await useCase(GetFinancesParams(
    clubId: clubIdAsync,
    year: selected.year,
    month: selected.month,
  ));

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
  final result = await useCase(GetFinanceSummaryParams(clubId: clubId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
});

// ── Finance categories provider ────────────────────────────────────────────────

final financeCategoriesProvider =
    FutureProvider.autoDispose<List<FinanceCategory>>((ref) async {
  final useCase = ref.read(getFinanceCategoriesUseCaseProvider);
  final result = await useCase();
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
  final result = await repo.getTransaction(financeId: id);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (t) => t,
  );
});
