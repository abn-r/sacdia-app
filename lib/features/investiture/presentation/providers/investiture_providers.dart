import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/investiture_remote_data_source.dart';
import '../../data/repositories/investiture_repository_impl.dart';
import '../../domain/entities/investiture_pending.dart';
import '../../domain/entities/investiture_history_entry.dart';
import '../../domain/repositories/investiture_repository.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Provider para el data source remoto de investidura.
final investitureRemoteDataSourceProvider =
    Provider<InvestitureRemoteDataSource>((ref) {
  return InvestitureRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

/// Provider para el repositorio de investidura.
final investitureRepositoryProvider =
    Provider<InvestitureRepository>((ref) {
  return InvestitureRepositoryImpl(
    remoteDataSource: ref.read(investitureRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Data providers ────────────────────────────────────────────────────────────

/// Provider para la lista paginada de investiduras pendientes.
///
/// Solo disponible para coordinadores/admins (GlobalRolesGuard).
final pendingInvestituresProvider =
    FutureProvider.autoDispose<List<InvestiturePending>>((ref) async {
  final repository = ref.read(investitureRepositoryProvider);
  final result = await repository.getPendingInvestitures();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (list) => list,
  );
});

/// Provider para el historial de investidura de un enrollment específico.
///
/// Family por [enrollmentId].
final investitureHistoryProvider =
    FutureProvider.autoDispose.family<List<InvestitureHistoryEntry>, int>(
        (ref, enrollmentId) async {
  final repository = ref.read(investitureRepositoryProvider);
  final result =
      await repository.getInvestitureHistory(enrollmentId: enrollmentId);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (history) => history,
  );
});

// ── Mutation state ────────────────────────────────────────────────────────────

/// Estado compartido para operaciones de investidura (submit, approve, reject, invest).
class InvestitureActionState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const InvestitureActionState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  InvestitureActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return InvestitureActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

// ── Submit for validation notifier ───────────────────────────────────────────

/// Notifier para enviar un enrollment a validación (director/consejero).
///
/// Family por [enrollmentId].
class SubmitForValidationNotifier
    extends AutoDisposeFamilyNotifier<InvestitureActionState, int> {
  @override
  InvestitureActionState build(int enrollmentId) =>
      const InvestitureActionState();

  /// Envía el enrollment para validación.
  Future<bool> submit({required int clubId, String? comments}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(investitureRepositoryProvider)
        .submitForValidation(
          enrollmentId: arg,
          clubId: clubId,
          comments: comments,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        // Invalidar la lista de pendientes para forzar recarga
        ref.invalidate(pendingInvestituresProvider);
        ref.invalidate(investitureHistoryProvider(arg));
        return true;
      },
    );
  }

  void reset() => state = const InvestitureActionState();
}

final submitForValidationNotifierProvider = NotifierProvider.autoDispose
    .family<SubmitForValidationNotifier, InvestitureActionState, int>(
  SubmitForValidationNotifier.new,
);

// ── Validate enrollment notifier ─────────────────────────────────────────────

/// Notifier para aprobar o rechazar un enrollment (coordinador/admin).
///
/// Family por [enrollmentId].
class ValidateEnrollmentNotifier
    extends AutoDisposeFamilyNotifier<InvestitureActionState, int> {
  @override
  InvestitureActionState build(int enrollmentId) =>
      const InvestitureActionState();

  /// Aprueba el enrollment.
  Future<bool> approve({String? comments}) async {
    return _validate(action: 'APPROVED', comments: comments);
  }

  /// Rechaza el enrollment. [comments] es requerido por el backend.
  Future<bool> reject({required String comments}) async {
    return _validate(action: 'REJECTED', comments: comments);
  }

  Future<bool> _validate({
    required String action,
    String? comments,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(investitureRepositoryProvider)
        .validateEnrollment(
          enrollmentId: arg,
          action: action,
          comments: comments,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(pendingInvestituresProvider);
        ref.invalidate(investitureHistoryProvider(arg));
        return true;
      },
    );
  }

  void reset() => state = const InvestitureActionState();
}

final validateEnrollmentNotifierProvider = NotifierProvider.autoDispose
    .family<ValidateEnrollmentNotifier, InvestitureActionState, int>(
  ValidateEnrollmentNotifier.new,
);

// ── Mark as investido notifier ────────────────────────────────────────────────

/// Notifier para registrar la investidura física de un miembro (coordinador/admin).
///
/// Family por [enrollmentId].
class MarkAsInvestidoNotifier
    extends AutoDisposeFamilyNotifier<InvestitureActionState, int> {
  @override
  InvestitureActionState build(int enrollmentId) =>
      const InvestitureActionState();

  Future<bool> markInvestido({String? comments}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(investitureRepositoryProvider)
        .markAsInvestido(
          enrollmentId: arg,
          comments: comments,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(pendingInvestituresProvider);
        ref.invalidate(investitureHistoryProvider(arg));
        return true;
      },
    );
  }

  void reset() => state = const InvestitureActionState();
}

final markAsInvestidoNotifierProvider = NotifierProvider.autoDispose
    .family<MarkAsInvestidoNotifier, InvestitureActionState, int>(
  MarkAsInvestidoNotifier.new,
);
