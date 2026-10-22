import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/coordinator_remote_data_source.dart';
import '../../data/repositories/coordinator_repository_impl.dart';
import '../../domain/entities/coordinator_club.dart';
import '../../domain/entities/coordinator_scope.dart';
import '../../domain/entities/sla_dashboard.dart';
import '../../domain/entities/evidence_review_item.dart';
import '../../domain/repositories/coordinator_repository.dart';

// ── Load errors ───────────────────────────────────────────────────────────────

/// Error raised by the coordinator read providers.
///
/// Keeps the historical `Exception: <message>` text (some views still strip
/// that prefix) while exposing [isForbidden] so views can show the
/// access-restricted state without sniffing the message.
class CoordinatorLoadException implements Exception {
  const CoordinatorLoadException(this.message, {this.isForbidden = false});

  factory CoordinatorLoadException.fromFailure(Failure failure) =>
      CoordinatorLoadException(
        failure.message,
        isForbidden: failure.code == 403,
      );

  final String message;
  final bool isForbidden;

  @override
  String toString() => 'Exception: $message';
}

/// Whether [error] means the user lacks permission for the coordinator API
/// (HTTP 403). Falls back to the legacy message match for errors that did not
/// come through [CoordinatorLoadException].
bool isCoordinatorForbidden(Object error) {
  if (error is CoordinatorLoadException) return error.isForbidden;
  final msg = error.toString();
  return msg.contains('permiso') || msg.contains('403');
}

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Provider para el data source remoto del coordinador.
final coordinatorRemoteDataSourceProvider =
    Provider<CoordinatorRemoteDataSource>((ref) {
  return CoordinatorRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

/// Provider para el repositorio del coordinador.
final coordinatorRepositoryProvider = Provider<CoordinatorRepository>((ref) {
  return CoordinatorRepositoryImpl(
    remoteDataSource: ref.read(coordinatorRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Scope ───────────────────────────────────────────────────────────────────

/// Alcance efectivo del coordinador actual.
final coordinatorScopeProvider =
    FutureProvider.autoDispose<CoordinatorScope>((ref) async {
  final repository = ref.read(coordinatorRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getMyScope(cancelToken: cancelToken);
  return result.fold(
    (failure) => throw CoordinatorLoadException.fromFailure(failure),
    (scope) => scope,
  );
});

// ── Clubs list ────────────────────────────────────────────────────────────────

/// Texto de búsqueda para filtrar clubs en la lista del coordinador.
final coordinatorClubSearchProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

/// Lista completa de clubs cargada desde el backend (sin filtrar).
final coordinatorClubsRawProvider =
    FutureProvider.autoDispose<List<CoordinatorClub>>((ref) async {
  final repository = ref.read(coordinatorRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.listClubs(cancelToken: cancelToken);
  return result.fold(
    (failure) => throw CoordinatorLoadException.fromFailure(failure),
    (clubs) => clubs,
  );
});

/// Lista de clubs filtrada por el texto de búsqueda.
final coordinatorClubsProvider =
    Provider.autoDispose<AsyncValue<List<CoordinatorClub>>>((ref) {
  final rawAsync = ref.watch(coordinatorClubsRawProvider);
  final query = ref.watch(coordinatorClubSearchProvider).trim().toLowerCase();

  return rawAsync.whenData((clubs) {
    if (query.isEmpty) return clubs;
    return clubs.where((c) => c.name.toLowerCase().contains(query)).toList();
  });
});

// ── SLA Dashboard ─────────────────────────────────────────────────────────────

/// Provider del dashboard SLA del coordinador.
final slaDashboardProvider =
    FutureProvider.autoDispose<SlaDashboard>((ref) async {
  final repository = ref.read(coordinatorRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getSlaDashboard(cancelToken: cancelToken);
  return result.fold(
    (failure) => throw CoordinatorLoadException.fromFailure(failure),
    (dashboard) => dashboard,
  );
});

// ── Evidence Review ───────────────────────────────────────────────────────────

/// Filtro de tipo activo en la vista de revisión de evidencias.
final evidenceTypeFilterProvider =
    StateProvider.autoDispose<EvidenceReviewType?>((ref) => null);

/// Cola de evidencias pendientes cargada página a página.
class PendingEvidenceState {
  const PendingEvidenceState({
    required this.items,
    required this.total,
    required this.page,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  factory PendingEvidenceState.firstPage(EvidenceReviewPage page) =>
      PendingEvidenceState(
        items: page.items,
        total: page.total,
        page: page.page,
        hasMore: page.hasMore && page.items.isNotEmpty,
      );

  /// Evidencias cargadas hasta ahora (todas las páginas pedidas).
  final List<EvidenceReviewItem> items;

  /// Pendientes en el servidor para este filtro; null si no lo informó.
  final int? total;

  /// Última página cargada.
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  /// La última llamada a [PendingEvidenceNotifier.loadMore] falló; la lista
  /// cargada sigue siendo válida.
  final bool loadMoreFailed;

  /// Agrega [next] (la página siguiente a [page]) sin duplicar ítems: con
  /// paginación por offset, una evidencia puede repetirse si la cola cambió
  /// entre páginas.
  PendingEvidenceState append(EvidenceReviewPage next) {
    final seen = {for (final i in items) (i.type, i.id)};
    return PendingEvidenceState(
      items: [
        ...items,
        ...next.items.where((i) => seen.add((i.type, i.id))),
      ],
      total: next.total ?? total,
      page: page + 1,
      hasMore: next.hasMore && next.items.isNotEmpty,
    );
  }

  PendingEvidenceState copyWith({bool? isLoadingMore, bool? loadMoreFailed}) =>
      PendingEvidenceState(
        items: items,
        total: total,
        page: page,
        hasMore: hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

/// Cola paginada de evidencias pendientes.
///
/// Family por [EvidenceReviewType?] — null significa todos los tipos. `build`
/// carga la primera página; [loadMore] agrega la siguiente. Invalidar el
/// provider (pull to refresh, aprobar/rechazar) vuelve a la página 1.
class PendingEvidenceNotifier extends AutoDisposeFamilyAsyncNotifier<
    PendingEvidenceState, EvidenceReviewType?> {
  /// Token de la carga actual; se cancela al invalidar o descartar el
  /// provider, así una página que llega tarde no pisa la lista nueva.
  CancelToken? _cancelToken;

  @override
  Future<PendingEvidenceState> build(EvidenceReviewType? arg) async {
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    ref.onDispose(cancelToken.cancel);
    final page = await fetchPage(1, cancelToken: cancelToken);
    return PendingEvidenceState.firstPage(page);
  }

  /// Pide la página [page] del filtro [arg] al repositorio.
  @visibleForOverriding
  Future<EvidenceReviewPage> fetchPage(
    int page, {
    CancelToken? cancelToken,
  }) async {
    final result =
        await ref.read(coordinatorRepositoryProvider).getPendingEvidence(
              page: page,
              type: arg,
              cancelToken: cancelToken,
            );
    return result.fold(
      (failure) => throw CoordinatorLoadException.fromFailure(failure),
      (page) => page,
    );
  }

  /// Carga la página siguiente. No hace nada si ya está cargando, si no hay
  /// más páginas o si la primera página aún no llegó.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (state.isLoading ||
        current == null ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    final cancelToken = _cancelToken;
    bool stale() =>
        cancelToken != _cancelToken || (cancelToken?.isCancelled ?? true);

    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    try {
      final next = await fetchPage(current.page + 1, cancelToken: cancelToken);
      if (stale()) return;
      state = AsyncData(current.append(next));
    } catch (_) {
      if (stale()) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreFailed: true),
      );
    }
  }
}

final pendingEvidenceProvider = AsyncNotifierProvider.autoDispose
    .family<PendingEvidenceNotifier, PendingEvidenceState, EvidenceReviewType?>(
  PendingEvidenceNotifier.new,
);

/// Provider para el detalle de una evidencia específica.
///
/// Family por [(EvidenceReviewType, String)] — tipo e ID.
typedef EvidenceDetailKey = ({EvidenceReviewType type, String id});

final evidenceDetailProvider = FutureProvider.autoDispose
    .family<EvidenceReviewItem, EvidenceDetailKey>((ref, key) async {
  final repository = ref.read(coordinatorRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getEvidenceDetail(
    type: key.type,
    id: key.id,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw CoordinatorLoadException.fromFailure(failure),
    (item) => item,
  );
});

// ── Evidence Action State ─────────────────────────────────────────────────────

/// Estado de una operación sobre una evidencia (approve/reject).
class EvidenceActionState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const EvidenceActionState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  EvidenceActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return EvidenceActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

/// Notifier para aprobar/rechazar una evidencia individual.
///
/// Family por [EvidenceDetailKey].
class EvidenceReviewNotifier
    extends AutoDisposeFamilyNotifier<EvidenceActionState, EvidenceDetailKey> {
  @override
  EvidenceActionState build(EvidenceDetailKey arg) =>
      const EvidenceActionState();

  /// Refreshes everything that shows this evidence: the pending list (every
  /// filter), this detail and the hub/SLA counters.
  void _invalidateAfterReview() {
    ref.invalidate(pendingEvidenceProvider);
    ref.invalidate(evidenceDetailProvider(arg));
    ref.invalidate(slaDashboardProvider);
  }

  Future<bool> approve({String? comment}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(coordinatorRepositoryProvider)
        .approveEvidence(type: arg.type, id: arg.id, comment: comment);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        _invalidateAfterReview();
        return true;
      },
    );
  }

  Future<bool> reject({required String rejectionReason}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref.read(coordinatorRepositoryProvider).rejectEvidence(
          type: arg.type,
          id: arg.id,
          rejectionReason: rejectionReason,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        _invalidateAfterReview();
        return true;
      },
    );
  }

  void reset() => state = const EvidenceActionState();
}

final evidenceReviewNotifierProvider = NotifierProvider.autoDispose
    .family<EvidenceReviewNotifier, EvidenceActionState, EvidenceDetailKey>(
  EvidenceReviewNotifier.new,
);
