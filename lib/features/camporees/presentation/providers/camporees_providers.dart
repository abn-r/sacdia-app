import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/models/paginated_result.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/camporees_remote_data_source.dart';
import '../../data/repositories/camporees_repository_impl.dart';
import '../../domain/entities/camporee.dart';
import '../../domain/entities/camporee_event.dart';
import '../../domain/entities/camporee_judge_assignment.dart';
import '../../domain/entities/camporee_member.dart';
import '../../domain/entities/camporee_payment.dart';
import '../../domain/entities/camporee_rubric.dart';
import '../../domain/entities/camporee_score_submission.dart';
import '../../domain/entities/camporee_section_registration.dart';
import '../../domain/repositories/camporees_repository.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Provider para el data source remoto de camporees
final camporeesRemoteDataSourceProvider =
    Provider<CamporeesRemoteDataSource>((ref) {
  return CamporeesRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

/// Provider para el repositorio de camporees
final camporeesRepositoryProvider = Provider<CamporeesRepository>((ref) {
  return CamporeesRepositoryImpl(
    remoteDataSource: ref.read(camporeesRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Data providers ────────────────────────────────────────────────────────────

/// Provider para la lista de camporees activos.
final camporeesProvider =
    FutureProvider.autoDispose<List<Camporee>>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repository = ref.read(camporeesRepositoryProvider);
  final result =
      await repository.getCamporees(active: true, cancelToken: cancelToken);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (camporees) => camporees,
  );
});

/// Provider para el detalle de un camporee específico.
///
/// Family por [camporeeId].
///
/// Cache-first: antes de ir al network, verifica si el camporee ya está
/// cargado en [camporeesProvider] (lista activa). El modelo de lista y el
/// de detalle tienen el mismo esquema, por lo que reutilizar el objeto
/// evita una llamada de red redundante al navegar desde la lista.
/// Si el camporee no está en caché (p.ej. navegación por deep link),
/// se realiza la llamada al endpoint de detalle normalmente.
final camporeeDetailProvider =
    FutureProvider.autoDispose.family<Camporee, int>((ref, camporeeId) async {
  // Check the already-loaded list first to avoid a redundant network call.
  final cachedList = ref.read(camporeesProvider).valueOrNull;
  if (cachedList != null) {
    Camporee? cached;
    for (final c in cachedList) {
      if (c.camporeeId == camporeeId) {
        cached = c;
        break;
      }
    }
    if (cached != null) return cached;
  }

  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repository = ref.read(camporeesRepositoryProvider);
  final result =
      await repository.getCamporeeDetail(camporeeId, cancelToken: cancelToken);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (camporee) => camporee,
  );
});

/// Inscripción contextual de la sección activa del actor autenticado.
///
/// El backend resuelve la sección y los permisos; el cliente solo conserva
/// el [camporeeId] como clave de caché.
final camporeeSectionRegistrationProvider = FutureProvider.autoDispose
    .family<CamporeeSectionRegistration, int>((ref, camporeeId) async {
  final repository = ref.read(camporeesRepositoryProvider);
  final result = await repository.getActiveSectionRegistration(camporeeId);

  return result.fold(
    (failure) => throw failure,
    (registration) => registration,
  );
});

/// Provider para eventos registrados en un camporee.
final camporeeEventsProvider = FutureProvider.autoDispose
    .family<List<CamporeeEvent>, int>((ref, camporeeId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repository = ref.read(camporeesRepositoryProvider);
  final result = await repository.getCamporeeEvents(
    camporeeId,
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (events) => events,
  );
});

/// Base provider que realiza la llamada real al repositorio para los miembros
/// paginados de un camporee (page 1, limit 50).
///
/// Al ser un `FutureProvider.autoDispose.family`, Riverpod deduplica por key:
/// dos watchers del mismo [camporeeId] comparten UNA sola request en vuelo.
/// Tanto [camporeeMembersProvider] como [camporeeMembersMetaProvider] consumen
/// este provider, eliminando la llamada de red duplicada.
///
/// Family por [camporeeId] (int).
final _camporeeMembersPaginatedProvider = FutureProvider.autoDispose
    .family<PaginatedResult<CamporeeMember>, int>((ref, camporeeId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repository = ref.read(camporeesRepositoryProvider);
  final result = await repository.getCamporeeMembers(
    camporeeId,
    page: 1,
    limit: 50,
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (paginated) => paginated,
  );
});

/// Provider para los miembros inscritos en un camporee (page 1, limit 50).
///
/// Family por [camporeeId]. Expone `List<CamporeeMember>` para que los widgets
/// existentes no requieran cambios.
///
/// Internamente observa [_camporeeMembersPaginatedProvider] — Riverpod garantiza
/// que compartir ese provider no dispara una segunda request de red.
///
/// TODO(pagination): convertir a un AsyncNotifier con load-more / infinite
/// scroll cuando se requiera paginación completa en la UI.
final camporeeMembersProvider = FutureProvider.autoDispose
    .family<List<CamporeeMember>, int>((ref, camporeeId) async {
  final paginated =
      await ref.watch(_camporeeMembersPaginatedProvider(camporeeId).future);
  return paginated.data;
});

/// Provider que expone los metadatos de paginación de los miembros de un camporee.
///
/// Útil para mostrar totales (p.ej. "120 inscriptos") sin cambiar la UI de lista.
/// Family por [camporeeId].
///
/// Comparte la misma request de red que [camporeeMembersProvider] vía
/// [_camporeeMembersPaginatedProvider].
final camporeeMembersMetaProvider = FutureProvider.autoDispose
    .family<PaginationMeta?, int>((ref, camporeeId) async {
  final paginated =
      await ref.watch(_camporeeMembersPaginatedProvider(camporeeId).future);
  return paginated.meta;
});

/// IDs de usuarios que ya están seleccionados/inscritos para asistir al camporee.
///
/// Consulta estados visibles para asistencia (`registered`, `pending_approval`,
/// `approved`) y pagina hasta agotar resultados para que el selector de miembros
/// pueda marcar registros ya enviados anteriormente, incluso si están pendientes
/// de aprobación por inscripción tardía.
final camporeeRegisteredUserIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, int>((ref, camporeeId) async {
  final repository = ref.read(camporeesRepositoryProvider);
  const statuses = ['registered', 'pending_approval', 'approved'];
  final ids = <String>{};

  for (final status in statuses) {
    var page = 1;
    var hasNextPage = true;

    while (hasNextPage) {
      final result = await repository.getCamporeeMembers(
        camporeeId,
        page: page,
        limit: 100,
        status: status,
      );

      final paginated = result.fold(
        (failure) => throw Exception(failure.message),
        (value) => value,
      );

      ids.addAll(paginated.data.map((member) => member.userId));
      hasNextPage = paginated.meta.hasNextPage;
      page += 1;
    }
  }

  return ids;
});

// ── Mutation notifiers ────────────────────────────────────────────────────────

enum RegisterCamporeeSectionStatus {
  idle,
  loading,
  success,
  failure,
}

/// Estado tipado para inscribir la sección activa en un camporee.
class RegisterCamporeeSectionState extends Equatable {
  final RegisterCamporeeSectionStatus status;
  final CamporeeSectionRegistration? registration;
  final Failure? failure;

  const RegisterCamporeeSectionState._({
    required this.status,
    this.registration,
    this.failure,
  });

  const RegisterCamporeeSectionState.idle()
      : this._(status: RegisterCamporeeSectionStatus.idle);

  const RegisterCamporeeSectionState.loading()
      : this._(status: RegisterCamporeeSectionStatus.loading);

  const RegisterCamporeeSectionState.success(
    CamporeeSectionRegistration registration,
  ) : this._(
          status: RegisterCamporeeSectionStatus.success,
          registration: registration,
        );

  const RegisterCamporeeSectionState.failure(Failure failure)
      : this._(
          status: RegisterCamporeeSectionStatus.failure,
          failure: failure,
        );

  bool get isIdle => status == RegisterCamporeeSectionStatus.idle;
  bool get isLoading => status == RegisterCamporeeSectionStatus.loading;
  bool get isSuccess => status == RegisterCamporeeSectionStatus.success;
  bool get hasFailure => status == RegisterCamporeeSectionStatus.failure;

  @override
  List<Object?> get props => [status, registration, failure];
}

/// Inscribe la sección activa resuelta por el backend.
class RegisterCamporeeSectionNotifier
    extends AutoDisposeFamilyNotifier<RegisterCamporeeSectionState, int> {
  bool _isRegistering = false;
  bool _isDisposed = false;

  @override
  RegisterCamporeeSectionState build(int camporeeId) {
    _isDisposed = false;
    ref.onDispose(() => _isDisposed = true);
    return const RegisterCamporeeSectionState.idle();
  }

  Future<bool> register() async {
    if (_isRegistering) return false;

    _isRegistering = true;
    state = const RegisterCamporeeSectionState.loading();
    final repository = ref.read(camporeesRepositoryProvider);

    try {
      final result = await repository.registerActiveSection(arg);

      return result.fold(
        (failure) {
          if (!_isDisposed) {
            state = RegisterCamporeeSectionState.failure(failure);
          }
          return false;
        },
        (registration) {
          if (_isDisposed) return true;

          state = RegisterCamporeeSectionState.success(registration);
          ref.invalidate(camporeeSectionRegistrationProvider(arg));
          ref.invalidate(camporeeDetailProvider(arg));
          ref.invalidate(camporeeEnrolledClubsProvider(arg));

          if (registration.enablesParticipants) {
            // Invalidar la fuente paginada refresca lista y metadatos derivados
            // sin reconstrucciones duplicadas.
            ref.invalidate(_camporeeMembersPaginatedProvider(arg));
            ref.invalidate(camporeeRegisteredUserIdsProvider(arg));
          }

          return true;
        },
      );
    } finally {
      _isRegistering = false;
    }
  }
}

final registerCamporeeSectionProvider = NotifierProvider.autoDispose
    .family<RegisterCamporeeSectionNotifier, RegisterCamporeeSectionState, int>(
  RegisterCamporeeSectionNotifier.new,
);

/// Estado para operaciones de registro de miembros en camporees.
class CamporeeRegistrationState {
  final bool isLoading;
  final String? errorMessage;
  final bool isInsuranceError;
  final bool success;

  const CamporeeRegistrationState({
    this.isLoading = false,
    this.errorMessage,
    this.isInsuranceError = false,
    this.success = false,
  });

  CamporeeRegistrationState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isInsuranceError,
    bool? success,
  }) {
    return CamporeeRegistrationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isInsuranceError: isInsuranceError ?? this.isInsuranceError,
      success: success ?? this.success,
    );
  }
}

/// Resultado de una inscripción múltiple.
class CamporeeRegistrationBatchResult {
  final int successCount;
  final int failureCount;
  final String? firstErrorMessage;

  const CamporeeRegistrationBatchResult({
    required this.successCount,
    required this.failureCount,
    this.firstErrorMessage,
  });

  bool get isSuccess => failureCount == 0;
  bool get hasAnySuccess => successCount > 0;
}

/// Notifier para manejar el registro de miembros en camporees.
///
/// Family por [camporeeId].
class CamporeeRegistrationNotifier
    extends AutoDisposeFamilyNotifier<CamporeeRegistrationState, int> {
  @override
  CamporeeRegistrationState build(int camporeeId) =>
      const CamporeeRegistrationState();

  int get _camporeeId => arg;

  /// Registra un miembro en el camporee.
  Future<bool> register({
    required String userId,
    String? camporeeType,
    String? clubName,
    required int insuranceId,
  }) async {
    state = state.copyWith(
        isLoading: true,
        errorMessage: null,
        isInsuranceError: false,
        success: false);

    final result = await ref.read(camporeesRepositoryProvider).registerMember(
          _camporeeId,
          userId: userId,
          camporeeType: camporeeType,
          clubName: clubName,
          insuranceId: insuranceId,
        );

    return result.fold(
      (failure) {
        final isInsuranceError = failure.code == 403 ||
            (failure.message.toLowerCase().contains('seguro') ||
                failure.message.toLowerCase().contains('insurance'));
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
          isInsuranceError: isInsuranceError,
        );
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(camporeeMembersProvider(_camporeeId));
        ref.invalidate(camporeeRegisteredUserIdsProvider(_camporeeId));
        ref.invalidate(camporeeDetailProvider(_camporeeId));
        return true;
      },
    );
  }

  /// Registra múltiples miembros en el camporee usando el contrato individual
  /// existente del backend.
  Future<CamporeeRegistrationBatchResult> registerMany({
    required Map<String, int> insuranceIdsByUserId,
  }) async {
    final registrations = insuranceIdsByUserId.entries.toList();

    if (registrations.isEmpty) {
      return const CamporeeRegistrationBatchResult(
        successCount: 0,
        failureCount: 0,
      );
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isInsuranceError: false,
      success: false,
    );

    var successCount = 0;
    var failureCount = 0;
    String? firstErrorMessage;
    var hasInsuranceError = false;

    for (final registration in registrations) {
      final result = await ref.read(camporeesRepositoryProvider).registerMember(
            _camporeeId,
            userId: registration.key,
            insuranceId: registration.value,
          );

      result.fold(
        (failure) {
          failureCount += 1;
          firstErrorMessage ??= failure.message;
          hasInsuranceError = hasInsuranceError ||
              failure.code == 403 ||
              failure.message.toLowerCase().contains('seguro') ||
              failure.message.toLowerCase().contains('insurance');
        },
        (_) {
          successCount += 1;
        },
      );
    }

    if (successCount > 0) {
      ref.invalidate(camporeeMembersProvider(_camporeeId));
      ref.invalidate(camporeeRegisteredUserIdsProvider(_camporeeId));
      ref.invalidate(camporeeDetailProvider(_camporeeId));
    }

    state = state.copyWith(
      isLoading: false,
      success: failureCount == 0,
      errorMessage: firstErrorMessage,
      isInsuranceError: hasInsuranceError,
    );

    return CamporeeRegistrationBatchResult(
      successCount: successCount,
      failureCount: failureCount,
      firstErrorMessage: firstErrorMessage,
    );
  }

  /// Limpia el estado de error / éxito.
  void reset() => state = const CamporeeRegistrationState();
}

/// Provider para el notifier de registro en camporees.
///
/// Family por [camporeeId].
final camporeeRegistrationNotifierProvider = NotifierProvider.autoDispose
    .family<CamporeeRegistrationNotifier, CamporeeRegistrationState, int>(
  CamporeeRegistrationNotifier.new,
);

/// Estado para operaciones de remoción de miembros de camporees.
class CamporeeRemoveMemberState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const CamporeeRemoveMemberState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  CamporeeRemoveMemberState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return CamporeeRemoveMemberState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

/// Notifier para remover miembros de un camporee.
///
/// Family por [camporeeId].
class CamporeeRemoveMemberNotifier
    extends AutoDisposeFamilyNotifier<CamporeeRemoveMemberState, int> {
  @override
  CamporeeRemoveMemberState build(int camporeeId) =>
      const CamporeeRemoveMemberState();

  int get _camporeeId => arg;

  /// Remueve un miembro del camporee.
  Future<bool> remove(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(camporeesRepositoryProvider)
        .removeMember(_camporeeId, userId);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(camporeeMembersProvider(_camporeeId));
        ref.invalidate(camporeeRegisteredUserIdsProvider(_camporeeId));
        return true;
      },
    );
  }

  void reset() => state = const CamporeeRemoveMemberState();
}

/// Provider para el notifier de remoción de miembros.
///
/// Family por [camporeeId].
final camporeeRemoveMemberNotifierProvider = NotifierProvider.autoDispose
    .family<CamporeeRemoveMemberNotifier, CamporeeRemoveMemberState, int>(
  CamporeeRemoveMemberNotifier.new,
);

// ── Payment providers ─────────────────────────────────────────────────────────

/// Parámetros para el provider de pagos de un miembro en un camporee.
class CamporeePaymentParams {
  final int camporeeId;
  final String memberId;

  const CamporeePaymentParams({
    required this.camporeeId,
    required this.memberId,
  });

  @override
  bool operator ==(Object other) =>
      other is CamporeePaymentParams &&
      other.camporeeId == camporeeId &&
      other.memberId == memberId;

  @override
  int get hashCode => Object.hash(camporeeId, memberId);
}

/// Provider para los pagos de un miembro en un camporee.
final camporeeMemberPaymentsProvider = FutureProvider.autoDispose
    .family<List<CamporeePayment>, CamporeePaymentParams>((ref, params) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repo = ref.read(camporeesRepositoryProvider);
  final result = await repo.getMemberPayments(
    params.camporeeId,
    params.memberId,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (payments) => payments,
  );
});

/// Provider para todos los pagos de un camporee.
final camporeeAllPaymentsProvider = FutureProvider.autoDispose
    .family<List<CamporeePayment>, int>((ref, camporeeId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repo = ref.read(camporeesRepositoryProvider);
  final result =
      await repo.getCamporeePayments(camporeeId, cancelToken: cancelToken);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (payments) => payments,
  );
});

/// Provider para los clubes inscritos en un camporee.
final camporeeEnrolledClubsProvider = FutureProvider.autoDispose
    .family<List<CamporeeEnrolledClub>, int>((ref, camporeeId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repo = ref.read(camporeesRepositoryProvider);
  final result =
      await repo.getEnrolledClubs(camporeeId, cancelToken: cancelToken);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (clubs) => clubs,
  );
});

// ── Create Payment notifier ───────────────────────────────────────────────────

class CreateCamporeePaymentState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const CreateCamporeePaymentState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  CreateCamporeePaymentState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return CreateCamporeePaymentState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

class CreateCamporeePaymentNotifier extends AutoDisposeFamilyNotifier<
    CreateCamporeePaymentState, CamporeePaymentParams> {
  @override
  CreateCamporeePaymentState build(CamporeePaymentParams arg) =>
      const CreateCamporeePaymentState();

  Future<bool> create({
    required double amount,
    required String paymentType,
    String? reference,
    DateTime? paymentDate,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref.read(camporeesRepositoryProvider).createPayment(
          arg.camporeeId,
          arg.memberId,
          amount: amount,
          paymentType: paymentType,
          reference: reference,
          paymentDate: paymentDate,
          notes: notes,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(camporeeMemberPaymentsProvider(arg));
        ref.invalidate(camporeeAllPaymentsProvider(arg.camporeeId));
        return true;
      },
    );
  }

  void reset() => state = const CreateCamporeePaymentState();
}

final createCamporeePaymentProvider = NotifierProvider.autoDispose.family<
    CreateCamporeePaymentNotifier,
    CreateCamporeePaymentState,
    CamporeePaymentParams>(
  CreateCamporeePaymentNotifier.new,
);

// ── Enroll Club notifier ──────────────────────────────────────────────────────

class EnrollClubState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const EnrollClubState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  EnrollClubState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return EnrollClubState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

class EnrollClubNotifier
    extends AutoDisposeFamilyNotifier<EnrollClubState, int> {
  @override
  EnrollClubState build(int camporeeId) => const EnrollClubState();

  int get _camporeeId => arg;

  Future<bool> enroll() async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result =
        await ref.read(camporeesRepositoryProvider).enrollClub(_camporeeId);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(camporeeEnrolledClubsProvider(_camporeeId));
        return true;
      },
    );
  }

  void reset() => state = const EnrollClubState();
}

final enrollClubNotifierProvider = NotifierProvider.autoDispose
    .family<EnrollClubNotifier, EnrollClubState, int>(
  EnrollClubNotifier.new,
);

// ── Camporee scoring providers ───────────────────────────────────────────────

/// Asignaciones del usuario actual como juez de camporee.
final camporeeJudgeAssignmentsProvider =
    FutureProvider.autoDispose<List<CamporeeJudgeAssignment>>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repository = ref.read(camporeesRepositoryProvider);
  final result = await repository.getMyJudgeAssignments(
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (assignments) => assignments,
  );
});

/// Rúbricas activas de un evento de camporee.
final camporeeEventRubricsProvider = FutureProvider.autoDispose
    .family<List<CamporeeRubric>, int>((ref, eventId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repository = ref.read(camporeesRepositoryProvider);
  final result = await repository.getCamporeeEventRubrics(
    eventId,
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (rubrics) => rubrics,
  );
});

class CamporeeJudgeScoreParams {
  final int eventId;
  final int clubSectionId;

  const CamporeeJudgeScoreParams({
    required this.eventId,
    required this.clubSectionId,
  });

  @override
  bool operator ==(Object other) =>
      other is CamporeeJudgeScoreParams &&
      other.eventId == eventId &&
      other.clubSectionId == clubSectionId;

  @override
  int get hashCode => Object.hash(eventId, clubSectionId);
}

class CamporeeScoreSubmissionState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const CamporeeScoreSubmissionState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  CamporeeScoreSubmissionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return CamporeeScoreSubmissionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

class CamporeeScoreSubmissionNotifier extends AutoDisposeFamilyNotifier<
    CamporeeScoreSubmissionState, CamporeeJudgeScoreParams> {
  @override
  CamporeeScoreSubmissionState build(CamporeeJudgeScoreParams arg) =>
      const CamporeeScoreSubmissionState();

  Future<bool> submit({
    required List<CamporeeScoreSubmissionItem> items,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result =
        await ref.read(camporeesRepositoryProvider).submitCamporeeEventScore(
              arg.eventId,
              arg.clubSectionId,
              submission: CamporeeScoreSubmission(
                source: 'judge_primary',
                notes: notes,
                items: items,
              ),
            );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(camporeeJudgeAssignmentsProvider);
        return true;
      },
    );
  }

  void reset() => state = const CamporeeScoreSubmissionState();
}

final camporeeScoreSubmissionProvider = NotifierProvider.autoDispose.family<
    CamporeeScoreSubmissionNotifier,
    CamporeeScoreSubmissionState,
    CamporeeJudgeScoreParams>(
  CamporeeScoreSubmissionNotifier.new,
);
