import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/certifications_remote_data_source.dart';
import '../../data/repositories/certifications_repository_impl.dart';
import '../../domain/entities/certification.dart';
import '../../domain/entities/certification_detail.dart';
import '../../domain/entities/certification_eligibility.dart';
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
  ref.keepAlive();
  final repository = ref.read(certificationsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getCertifications(cancelToken: cancelToken);

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
/// `List<CertificationModule>` with nested sections. The detail view renders
/// that module/section tree and computes totalSections from it, so the network
/// call to GET /certifications/{id} is always required.
final certificationDetailProvider = FutureProvider.autoDispose
    .family<CertificationDetail, int>((ref, certificationId) async {
  final repository = ref.read(certificationsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getCertificationDetail(
    certificationId,
    cancelToken: cancelToken,
  );

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
    throw Exception(tr('errors.user_not_authenticated'));
  }

  final repository = ref.read(certificationsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getUserCertifications(
    userId,
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (userCertifications) => userCertifications,
  );
});

/// Provider para el progreso detallado del usuario en una certificación específica.
///
/// Family por [certificationId]. Resuelve el userId internamente desde el authNotifier.
final certificationProgressProvider = FutureProvider.autoDispose
    .family<CertificationProgress, int>((ref, certificationId) async {
  final userId = await ref.watch(
    authNotifierProvider.selectAsync((user) => user?.id),
  );

  if (userId == null) {
    throw Exception(tr('errors.user_not_authenticated'));
  }

  final repository = ref.read(certificationsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getCertificationProgress(
    userId,
    certificationId,
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (progress) => progress,
  );
});

/// Elegibilidad de la persona para inscribirse en una certificación.
///
/// Family por [certificationId]. Sin caché entre pantallas: la pantalla de una
/// certificación disponible siempre muestra lo que dice el servidor ahora.
final certificationEligibilityProvider = FutureProvider.autoDispose
    .family<CertificationEligibility, int>((ref, certificationId) async {
  final userId = await ref.watch(
    authNotifierProvider.selectAsync((user) => user?.id),
  );
  if (userId == null) {
    throw Exception(tr('errors.user_not_authenticated'));
  }

  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result =
      await ref.read(certificationsRepositoryProvider).getEligibility(
            userId,
            certificationId,
            cancelToken: cancelToken,
          );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (eligibility) => eligibility,
  );
});

/// ¿Debe verse la feature de certificaciones? Sí cuando la persona ya tiene
/// una inscripción activa o es elegible para alguna certificación publicada.
///
/// Se calcula una vez por sesión (keepAlive) porque pide la elegibilidad de
/// cada certificación del catálogo; Mis clases y el perfil la comparten. Un
/// fallo de red NO es un «no»: si no hay ninguna elegible y alguna consulta
/// falló, el provider queda en error (la UI lo oculta) y se reintenta al
/// refrescar en lugar de recordar un falso negativo toda la sesión.
final certificationsAccessProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  ref.keepAlive();
  final userId = await ref.watch(
    authNotifierProvider.selectAsync((user) => user?.id),
  );
  if (userId == null) return false;

  try {
    final enrollments = await ref.watch(userCertificationsProvider.future);
    if (enrollments.any((e) => e.isEnrolled)) return true;
  } catch (_) {
    // Sin inscripciones legibles: se decide por la elegibilidad.
  }

  final catalog = await ref.watch(certificationsProvider.future);
  final published = catalog.where((c) => c.active).toList();
  if (published.isEmpty) return false;

  final repository = ref.read(certificationsRepositoryProvider);
  final results = await Future.wait([
    for (final c in published)
      repository.getEligibility(userId, c.certificationId),
  ]);
  var anyFailed = false;
  for (final result in results) {
    final eligible = result.fold<bool?>((_) => null, (e) => e.eligible);
    if (eligible == true) return true;
    if (eligible == null) anyFailed = true;
  }
  if (anyFailed) {
    throw Exception(tr('certifications.errors.get_eligibility'));
  }
  return false;
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
class CertificationEnrollmentNotifier
    extends Notifier<CertificationEnrollmentState> {
  CertificationEnrollmentNotifier(this.arg);

  final int arg;

  @override
  CertificationEnrollmentState build() => const CertificationEnrollmentState();

  String get _userId {
    final authState = ref.read(authNotifierProvider);
    return authState.value?.id ?? '';
  }

  int get _certificationId => arg;

  /// Inscribe al usuario en la certificación.
  Future<bool> enroll() =>
      // Callers only `ref.read` this notifier: keep it alive until the request
      // settles (see keepAliveDuring).
      ref.keepAliveDuring(() async {
        state =
            state.copyWith(isLoading: true, errorMessage: null, success: false);

        final result = await ref
            .read(certificationsRepositoryProvider)
            .enrollCertification(_userId, _certificationId);

        return result.fold<bool>(
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
            ref.invalidate(certificationsAccessProvider);
            return true;
          },
        );
      });

  /// Desinscribe al usuario de la certificación.
  Future<bool> unenroll() => ref.keepAliveDuring(() async {
        state =
            state.copyWith(isLoading: true, errorMessage: null, success: false);

        final result = await ref
            .read(certificationsRepositoryProvider)
            .unenrollCertification(_userId, _certificationId);

        return result.fold<bool>(
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
            ref.invalidate(certificationsAccessProvider);
            return true;
          },
        );
      });

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
