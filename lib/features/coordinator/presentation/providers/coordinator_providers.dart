import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/coordinator_remote_data_source.dart';
import '../../data/repositories/coordinator_repository_impl.dart';
import '../../domain/entities/sla_dashboard.dart';
import '../../domain/entities/evidence_review_item.dart';
import '../../domain/entities/camporee_approval.dart';
import '../../domain/repositories/coordinator_repository.dart';

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
final coordinatorRepositoryProvider =
    Provider<CoordinatorRepository>((ref) {
  return CoordinatorRepositoryImpl(
    remoteDataSource: ref.read(coordinatorRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── SLA Dashboard ─────────────────────────────────────────────────────────────

/// Provider del dashboard SLA del coordinador.
final slaDashboardProvider =
    FutureProvider.autoDispose<SlaDashboard>((ref) async {
  final repository = ref.read(coordinatorRepositoryProvider);
  final result = await repository.getSlaDashboard();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (dashboard) => dashboard,
  );
});

// ── Evidence Review ───────────────────────────────────────────────────────────

/// Filtro de tipo activo en la vista de revisión de evidencias.
final evidenceTypeFilterProvider =
    StateProvider.autoDispose<EvidenceReviewType?>((ref) => null);

/// Provider para la lista paginada de evidencias pendientes.
///
/// Family por [EvidenceReviewType?] — null significa todos los tipos.
final pendingEvidenceProvider = FutureProvider.autoDispose
    .family<List<EvidenceReviewItem>, EvidenceReviewType?>(
        (ref, type) async {
  final repository = ref.read(coordinatorRepositoryProvider);
  final result = await repository.getPendingEvidence(type: type);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (list) => list,
  );
});

/// Provider para el detalle de una evidencia específica.
///
/// Family por [(EvidenceReviewType, String)] — tipo e ID.
typedef EvidenceDetailKey = ({EvidenceReviewType type, String id});

final evidenceDetailProvider = FutureProvider.autoDispose
    .family<EvidenceReviewItem, EvidenceDetailKey>((ref, key) async {
  final repository = ref.read(coordinatorRepositoryProvider);
  final result = await repository.getEvidenceDetail(
    type: key.type,
    id: key.id,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
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
        ref.invalidate(pendingEvidenceProvider);
        ref.invalidate(evidenceDetailProvider(arg));
        return true;
      },
    );
  }

  Future<bool> reject({required String rejectionReason}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(coordinatorRepositoryProvider)
        .rejectEvidence(
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
        ref.invalidate(pendingEvidenceProvider);
        ref.invalidate(evidenceDetailProvider(arg));
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

// ── Camporee list ─────────────────────────────────────────────────────────────

/// Provider para la lista de camporees locales activos.
/// GET /camporees?active=true
final localCamporeeListProvider =
    FutureProvider.autoDispose<List<CamporeeItem>>((ref) async {
  final repository = ref.read(coordinatorRepositoryProvider);
  final result = await repository.listLocalCamporees(activeOnly: true);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (list) => list,
  );
});

/// Provider para la lista de camporees de unión activos.
/// GET /camporees/union
final unionCamporeeListProvider =
    FutureProvider.autoDispose<List<CamporeeItem>>((ref) async {
  final repository = ref.read(coordinatorRepositoryProvider);
  final result = await repository.listUnionCamporees();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (list) => list,
  );
});

// ── Selected camporee state ───────────────────────────────────────────────────

/// Camporee seleccionado en la vista de aprobaciones.
///
/// Es null cuando todavía no se eligió ningún camporee.
final selectedCamporeeProvider =
    StateProvider.autoDispose<CamporeeItem?>((ref) => null);

// ── Camporee pending approvals ────────────────────────────────────────────────

/// Key para identificar qué camporee pedir al endpoint de pending.
typedef CamporeePendingKey = ({int camporeeId, CamporeeScope scope});

/// Provider para las inscripciones pendientes de un camporee específico.
///
/// Family por [CamporeePendingKey] — incluye el id y el scope (local/union).
/// Devuelve el envelope completo { clubs, members, payments }.
final camporeePendingProvider = FutureProvider.autoDispose
    .family<CamporeePendingApprovals, CamporeePendingKey>(
        (ref, key) async {
  final repository = ref.read(coordinatorRepositoryProvider);
  final Either<Failure, CamporeePendingApprovals> result;

  if (key.scope == CamporeeScope.union) {
    result = await repository.getUnionCamporeePending(key.camporeeId);
  } else {
    result = await repository.getLocalCamporeePending(key.camporeeId);
  }

  return result.fold(
    (failure) => throw Exception(failure.message),
    (data) => data,
  );
});

// ── Camporee action state ─────────────────────────────────────────────────────

/// Estado de una operación de aprobación/rechazo.
class CamporeeApprovalActionState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const CamporeeApprovalActionState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  CamporeeApprovalActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return CamporeeApprovalActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

// ── Club enrollment notifier ──────────────────────────────────────────────────

/// Key para identificar una inscripción de club pendiente.
typedef CamporeeClubKey = ({
  int camporeeId,
  int camporeeClubId,
  CamporeeScope scope
});

class CamporeeClubApprovalNotifier extends AutoDisposeFamilyNotifier<
    CamporeeApprovalActionState, CamporeeClubKey> {
  @override
  CamporeeApprovalActionState build(CamporeeClubKey arg) =>
      const CamporeeApprovalActionState();

  Future<bool> approve() async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(coordinatorRepositoryProvider)
        .approveCamporeeClub(
          camporeeId: arg.camporeeId,
          camporeeClubId: arg.camporeeClubId,
          scope: arg.scope,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        _invalidatePending();
        return true;
      },
    );
  }

  Future<bool> reject({String? rejectionReason}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(coordinatorRepositoryProvider)
        .rejectCamporeeClub(
          camporeeId: arg.camporeeId,
          camporeeClubId: arg.camporeeClubId,
          scope: arg.scope,
          rejectionReason: rejectionReason,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        _invalidatePending();
        return true;
      },
    );
  }

  void _invalidatePending() {
    ref.invalidate(
      camporeePendingProvider(
        (camporeeId: arg.camporeeId, scope: arg.scope),
      ),
    );
  }

  void reset() => state = const CamporeeApprovalActionState();
}

final camporeeClubApprovalNotifierProvider = NotifierProvider.autoDispose
    .family<CamporeeClubApprovalNotifier, CamporeeApprovalActionState,
        CamporeeClubKey>(
  CamporeeClubApprovalNotifier.new,
);

// ── Member enrollment notifier ────────────────────────────────────────────────

/// Key para identificar una inscripción de miembro pendiente.
typedef CamporeeMemberKey = ({
  int camporeeId,
  int camporeeMemberId,
  CamporeeScope scope
});

class CamporeeMemberApprovalNotifier extends AutoDisposeFamilyNotifier<
    CamporeeApprovalActionState, CamporeeMemberKey> {
  @override
  CamporeeApprovalActionState build(CamporeeMemberKey arg) =>
      const CamporeeApprovalActionState();

  Future<bool> approve() async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(coordinatorRepositoryProvider)
        .approveCamporeeMember(
          camporeeId: arg.camporeeId,
          camporeeMemberId: arg.camporeeMemberId,
          scope: arg.scope,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        _invalidatePending();
        return true;
      },
    );
  }

  Future<bool> reject({String? rejectionReason}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(coordinatorRepositoryProvider)
        .rejectCamporeeMember(
          camporeeId: arg.camporeeId,
          camporeeMemberId: arg.camporeeMemberId,
          scope: arg.scope,
          rejectionReason: rejectionReason,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        _invalidatePending();
        return true;
      },
    );
  }

  void _invalidatePending() {
    ref.invalidate(
      camporeePendingProvider(
        (camporeeId: arg.camporeeId, scope: arg.scope),
      ),
    );
  }

  void reset() => state = const CamporeeApprovalActionState();
}

final camporeeMemberApprovalNotifierProvider = NotifierProvider.autoDispose
    .family<CamporeeMemberApprovalNotifier, CamporeeApprovalActionState,
        CamporeeMemberKey>(
  CamporeeMemberApprovalNotifier.new,
);

// ── Payment notifier ──────────────────────────────────────────────────────────

/// Key para identificar un pago pendiente.
/// [camporeePaymentId] es el ID de aprobación (String, puede ser UUID o int-string).
typedef CamporeePaymentKey = ({
  String camporeePaymentId,
  int camporeeId,
  CamporeeScope scope
});

class CamporeePaymentApprovalNotifier extends AutoDisposeFamilyNotifier<
    CamporeeApprovalActionState, CamporeePaymentKey> {
  @override
  CamporeeApprovalActionState build(CamporeePaymentKey arg) =>
      const CamporeeApprovalActionState();

  Future<bool> approve() async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(coordinatorRepositoryProvider)
        .approveCamporeePayment(
          camporeePaymentId: arg.camporeePaymentId,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        _invalidatePending();
        return true;
      },
    );
  }

  Future<bool> reject({String? rejectionReason}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(coordinatorRepositoryProvider)
        .rejectCamporeePayment(
          camporeePaymentId: arg.camporeePaymentId,
          rejectionReason: rejectionReason,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        _invalidatePending();
        return true;
      },
    );
  }

  void _invalidatePending() {
    ref.invalidate(
      camporeePendingProvider(
        (camporeeId: arg.camporeeId, scope: arg.scope),
      ),
    );
  }

  void reset() => state = const CamporeeApprovalActionState();
}

final camporeePaymentApprovalNotifierProvider = NotifierProvider.autoDispose
    .family<CamporeePaymentApprovalNotifier, CamporeeApprovalActionState,
        CamporeePaymentKey>(
  CamporeePaymentApprovalNotifier.new,
);
