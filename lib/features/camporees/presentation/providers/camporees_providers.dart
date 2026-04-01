import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/camporees_remote_data_source.dart';
import '../../data/repositories/camporees_repository_impl.dart';
import '../../domain/entities/camporee.dart';
import '../../domain/entities/camporee_member.dart';
import '../../domain/entities/camporee_payment.dart';
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
final camporeesRepositoryProvider =
    Provider<CamporeesRepository>((ref) {
  return CamporeesRepositoryImpl(
    remoteDataSource: ref.read(camporeesRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Data providers ────────────────────────────────────────────────────────────

/// Provider para la lista de camporees activos.
final camporeesProvider =
    FutureProvider.autoDispose<List<Camporee>>((ref) async {
  final repository = ref.read(camporeesRepositoryProvider);
  final result = await repository.getCamporees(active: true);

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
    FutureProvider.autoDispose.family<Camporee, int>(
        (ref, camporeeId) async {
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

  final repository = ref.read(camporeesRepositoryProvider);
  final result = await repository.getCamporeeDetail(camporeeId);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (camporee) => camporee,
  );
});

/// Provider para los miembros inscritos en un camporee.
///
/// Family por [camporeeId].
final camporeeMembersProvider =
    FutureProvider.autoDispose.family<List<CamporeeMember>, int>(
        (ref, camporeeId) async {
  final repository = ref.read(camporeesRepositoryProvider);
  final result = await repository.getCamporeeMembers(camporeeId);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (members) => members,
  );
});

// ── Mutation notifiers ────────────────────────────────────────────────────────

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
    required String camporeeType,
    String? clubName,
    int? insuranceId,
  }) async {
    state = state.copyWith(
        isLoading: true, errorMessage: null, isInsuranceError: false, success: false);

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
        ref.invalidate(camporeeDetailProvider(_camporeeId));
        return true;
      },
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
    state = state.copyWith(
        isLoading: true, errorMessage: null, success: false);

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
    .family<List<CamporeePayment>, CamporeePaymentParams>(
        (ref, params) async {
  final repo = ref.read(camporeesRepositoryProvider);
  final result = await repo.getMemberPayments(
    params.camporeeId,
    params.memberId,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (payments) => payments,
  );
});

/// Provider para todos los pagos de un camporee.
final camporeeAllPaymentsProvider =
    FutureProvider.autoDispose.family<List<CamporeePayment>, int>(
        (ref, camporeeId) async {
  final repo = ref.read(camporeesRepositoryProvider);
  final result = await repo.getCamporeePayments(camporeeId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (payments) => payments,
  );
});

/// Provider para los clubes inscritos en un camporee.
final camporeeEnrolledClubsProvider =
    FutureProvider.autoDispose.family<List<CamporeeEnrolledClub>, int>(
        (ref, camporeeId) async {
  final repo = ref.read(camporeesRepositoryProvider);
  final result = await repo.getEnrolledClubs(camporeeId);
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
    state = state.copyWith(
        isLoading: true, errorMessage: null, success: false);

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
        state = state.copyWith(
            isLoading: false, errorMessage: failure.message);
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

  Future<bool> enroll({required int clubSectionId}) async {
    state = state.copyWith(
        isLoading: true, errorMessage: null, success: false);

    final result = await ref.read(camporeesRepositoryProvider).enrollClub(
          _camporeeId,
          clubSectionId: clubSectionId,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(
            isLoading: false, errorMessage: failure.message);
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
