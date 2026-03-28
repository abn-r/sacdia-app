import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/certifications_remote_data_source.dart';
import '../../data/repositories/certifications_repository_impl.dart';
import '../../domain/entities/certification.dart';
import '../../domain/entities/certification_detail.dart';
import '../../domain/entities/user_certification.dart';
import '../../domain/entities/certification_progress.dart';
import '../../domain/repositories/certifications_repository.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Provider para el data source remoto de certificaciones
final certificationsRemoteDataSourceProvider =
    Provider<CertificationsRemoteDataSource>((ref) {
  return CertificationsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

/// Provider para el repositorio de certificaciones
final certificationsRepositoryProvider =
    Provider<CertificationsRepository>((ref) {
  return CertificationsRepositoryImpl(
    remoteDataSource: ref.read(certificationsRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Data providers ────────────────────────────────────────────────────────────

/// Provider para el catálogo completo de certificaciones.
final certificationsProvider =
    FutureProvider.autoDispose<List<Certification>>((ref) async {
  final repository = ref.read(certificationsRepositoryProvider);
  final result = await repository.getCertifications();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (certifications) => certifications,
  );
});

/// Provider para el detalle de una certificación específica.
///
/// Family por [certificationId].
///
/// NOTE: A cache-first lookup against [certificationsProvider] is intentionally
/// NOT applied here. [certificationsProvider] returns [Certification] objects
/// (name, description, active, modulesCount — no module tree), whereas this
/// provider returns [CertificationDetail] which includes the full
/// List<CertificationModule> with nested sections. The detail view renders
/// that module/section tree and computes totalSections from it, so the network
/// call to GET /certifications/{id} is always required.
final certificationDetailProvider =
    FutureProvider.autoDispose.family<CertificationDetail, int>(
        (ref, certificationId) async {
  final repository = ref.read(certificationsRepositoryProvider);
  final result =
      await repository.getCertificationDetail(certificationId);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (detail) => detail,
  );
});

/// Provider para las certificaciones en las que el usuario autenticado está inscrito.
final userCertificationsProvider =
    FutureProvider.autoDispose<List<UserCertification>>((ref) async {
  final userId = await ref.watch(
    authNotifierProvider.selectAsync((user) => user?.id),
  );

  if (userId == null) {
    throw Exception('Usuario no autenticado');
  }

  final repository = ref.read(certificationsRepositoryProvider);
  final result = await repository.getUserCertifications(userId);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (userCertifications) => userCertifications,
  );
});

/// Provider para el progreso detallado del usuario en una certificación específica.
///
/// Family por [certificationId]. Resuelve el userId internamente desde el authNotifier.
final certificationProgressProvider =
    FutureProvider.autoDispose.family<CertificationProgress, int>(
        (ref, certificationId) async {
  final userId = await ref.watch(
    authNotifierProvider.selectAsync((user) => user?.id),
  );

  if (userId == null) {
    throw Exception('Usuario no autenticado');
  }

  final repository = ref.read(certificationsRepositoryProvider);
  final result =
      await repository.getCertificationProgress(userId, certificationId);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (progress) => progress,
  );
});

// ── Mutation notifiers ────────────────────────────────────────────────────────

/// Estado para operaciones de inscripción/desinscripción en certificaciones.
class CertificationEnrollmentState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const CertificationEnrollmentState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  CertificationEnrollmentState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return CertificationEnrollmentState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

/// Notifier para manejar inscripción y desinscripción en certificaciones.
///
/// Es un family por [certificationId] para que cada certificación tenga su propio estado.
class CertificationEnrollmentNotifier extends AutoDisposeFamilyNotifier<
    CertificationEnrollmentState, int> {
  @override
  CertificationEnrollmentState build(int certificationId) =>
      const CertificationEnrollmentState();

  String get _userId {
    final authState = ref.read(authNotifierProvider);
    return authState.value?.id ?? '';
  }

  int get _certificationId => arg;

  /// Inscribe al usuario en la certificación.
  Future<bool> enroll() async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(certificationsRepositoryProvider)
        .enrollCertification(_userId, _certificationId);

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
        ref.invalidate(userCertificationsProvider);
        ref.invalidate(certificationProgressProvider(_certificationId));
        return true;
      },
    );
  }

  /// Desinscribe al usuario de la certificación.
  Future<bool> unenroll() async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(certificationsRepositoryProvider)
        .unenrollCertification(_userId, _certificationId);

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
        ref.invalidate(userCertificationsProvider);
        ref.invalidate(certificationProgressProvider(_certificationId));
        return true;
      },
    );
  }

  /// Limpia el estado de error / éxito.
  void reset() => state = const CertificationEnrollmentState();
}

/// Provider para el notifier de inscripción en certificaciones.
///
/// Family por [certificationId].
final certificationEnrollmentNotifierProvider = NotifierProvider.autoDispose
    .family<CertificationEnrollmentNotifier, CertificationEnrollmentState, int>(
  CertificationEnrollmentNotifier.new,
);

/// Notifier para actualizar el progreso de secciones en una certificación.
///
/// Family por [certificationId].
class SectionProgressNotifier
    extends AutoDisposeFamilyNotifier<CertificationEnrollmentState, int> {
  @override
  CertificationEnrollmentState build(int certificationId) =>
      const CertificationEnrollmentState();

  String get _userId {
    final authState = ref.read(authNotifierProvider);
    return authState.value?.id ?? '';
  }

  int get _certificationId => arg;

  /// Marca o desmarca una sección como completada.
  Future<bool> updateSection({
    required int moduleId,
    required int sectionId,
    required bool completed,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref
        .read(certificationsRepositoryProvider)
        .updateSectionProgress(
          _userId,
          _certificationId,
          moduleId,
          sectionId,
          completed,
        );

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
        ref.invalidate(certificationProgressProvider(_certificationId));
        ref.invalidate(userCertificationsProvider);
        return true;
      },
    );
  }

  /// Limpia el estado de error / éxito.
  void reset() => state = const CertificationEnrollmentState();
}

/// Provider para el notifier de progreso de sección.
///
/// Family por [certificationId].
final sectionProgressNotifierProvider = NotifierProvider.autoDispose
    .family<SectionProgressNotifier, CertificationEnrollmentState, int>(
  SectionProgressNotifier.new,
);
