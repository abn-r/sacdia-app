import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/honors_remote_data_source.dart';
import '../../data/repositories/honors_repository_impl.dart';
import '../../domain/entities/honor.dart';
import '../../domain/entities/honor_category.dart';
import '../../domain/entities/honor_group.dart';
import '../../domain/entities/honor_requirement.dart';
import '../../domain/entities/user_honor.dart';
import '../../domain/repositories/honors_repository.dart';
import '../../domain/usecases/get_honor_categories.dart';
import '../../domain/usecases/get_honor_requirements.dart';
import '../../domain/usecases/get_honors.dart';
import '../../domain/usecases/get_user_honor_progress.dart';
import '../../domain/usecases/get_user_honors.dart';
import '../../domain/usecases/register_user_honor.dart';
import '../../domain/usecases/start_honor.dart';
import '../../domain/usecases/update_requirement_progress.dart';

/// Provider para el data source remoto de especialidades
final honorsRemoteDataSourceProvider = Provider<HonorsRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);

  return HonorsRemoteDataSourceImpl(
    dio: dio,
    baseUrl: baseUrl,
  );
});

/// Provider para el repositorio de especialidades
final honorsRepositoryProvider = Provider<HonorsRepository>((ref) {
  final remoteDataSource = ref.read(honorsRemoteDataSourceProvider);
  final networkInfo = ref.read(networkInfoProvider);

  return HonorsRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

/// Provider para el caso de uso de obtener categorías
final getHonorCategoriesProvider = Provider<GetHonorCategories>((ref) {
  return GetHonorCategories(ref.read(honorsRepositoryProvider));
});

/// Provider para el caso de uso de obtener especialidades
final getHonorsProvider = Provider<GetHonors>((ref) {
  return GetHonors(ref.read(honorsRepositoryProvider));
});

/// Provider para el caso de uso de obtener especialidades de usuario
final getUserHonorsProvider = Provider<GetUserHonors>((ref) {
  return GetUserHonors(ref.read(honorsRepositoryProvider));
});

/// Provider para el caso de uso de iniciar especialidad
final startHonorProvider = Provider<StartHonor>((ref) {
  return StartHonor(ref.read(honorsRepositoryProvider));
});

/// Provider para el caso de uso de registrar especialidad completa
final registerUserHonorProvider = Provider<RegisterUserHonor>((ref) {
  return RegisterUserHonor(ref.read(honorsRepositoryProvider));
});

/// Provider para las categorías de especialidades
final honorCategoriesProvider = FutureProvider.autoDispose<List<HonorCategory>>((ref) async {
  final getHonorCategories = ref.read(getHonorCategoriesProvider);
  final result = await getHonorCategories(const NoParams());

  return result.fold(
    (failure) => throw Exception(failure.message),
    (categories) => categories,
  );
});

/// Provider para especialidades filtradas
final honorsProvider = FutureProvider.autoDispose
    .family<List<Honor>, GetHonorsParams>((ref, params) async {
  final getHonors = ref.read(getHonorsProvider);
  final result = await getHonors(params);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (honors) => honors,
  );
});

/// Provider para especialidades por categoría
final honorsByCategoryProvider =
    FutureProvider.autoDispose.family<List<Honor>, int>((ref, categoryId) async {
  final getHonors = ref.read(getHonorsProvider);
  final result = await getHonors(GetHonorsParams(categoryId: categoryId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (honors) => honors,
  );
});

/// Provider para las especialidades de un usuario.
/// keepAlive: el provider se mantiene vivo mientras el árbol esté montado,
/// evitando re-fetches al cambiar de tab y eliminando el retry loop 429.
final userHonorsProvider = FutureProvider<List<UserHonor>>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  final userId = authState.value?.id;

  if (userId == null) {
    throw Exception('Usuario no autenticado');
  }

  final getUserHonors = ref.read(getUserHonorsProvider);
  final result = await getUserHonors(GetUserHonorsParams(userId: userId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (userHonors) => userHonors,
  );
});

/// Provider para estadísticas de especialidades del usuario
final userHonorStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  final userId = authState.value?.id;

  if (userId == null) {
    throw Exception('Usuario no autenticado');
  }

  final repository = ref.read(honorsRepositoryProvider);
  final result = await repository.getUserHonorStats(userId);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (stats) => stats,
  );
});

/// Provider para especialidades agrupadas por categoría
final honorsGroupedByCategoryProvider = FutureProvider.autoDispose<List<HonorGroup>>((ref) async {
  final repository = ref.read(honorsRepositoryProvider);
  final result = await repository.getHonorsGroupedByCategory();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (groups) => groups,
  );
});

/// Notifier para manejar inscripciones en especialidades
class HonorEnrollmentNotifier extends AutoDisposeAsyncNotifier<UserHonor?> {
  @override
  Future<UserHonor?> build() async => null;

  /// Inscribir a un usuario en una especialidad
  Future<void> enrollInHonor(String userId, int honorId) async {
    state = const AsyncValue.loading();

    final result = await ref.read(startHonorProvider)(
      StartHonorParams(userId: userId, honorId: honorId),
    );

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (userHonor) => AsyncValue.data(userHonor),
    );
  }
}

/// Provider para el notifier de inscripción en especialidades
final honorEnrollmentNotifierProvider =
    AsyncNotifierProvider.autoDispose<HonorEnrollmentNotifier, UserHonor?>(() {
  return HonorEnrollmentNotifier();
});

// ── Registration Notifier ────────────────────────────────────────────────────

/// Estado del formulario de registro de especialidad
enum HonorRegistrationStatus { idle, loading, success, error }

class HonorRegistrationState {
  final HonorRegistrationStatus status;
  final UserHonor? result;
  final String? errorMessage;

  const HonorRegistrationState({
    this.status = HonorRegistrationStatus.idle,
    this.result,
    this.errorMessage,
  });

  HonorRegistrationState copyWith({
    HonorRegistrationStatus? status,
    UserHonor? result,
    String? errorMessage,
  }) {
    return HonorRegistrationState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier para manejar el registro completo de especialidades
class HonorRegistrationNotifier extends AutoDisposeNotifier<HonorRegistrationState> {
  @override
  HonorRegistrationState build() => const HonorRegistrationState();

  /// Registra la especialidad con los datos del formulario
  Future<bool> register(RegisterUserHonorParams params) async {
    state = state.copyWith(status: HonorRegistrationStatus.loading);

    final result = await ref.read(registerUserHonorProvider)(params);

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: HonorRegistrationStatus.error,
          errorMessage: failure.message,
        );
        return false;
      },
      (userHonor) {
        state = state.copyWith(
          status: HonorRegistrationStatus.success,
          result: userHonor,
        );
        return true;
      },
    );
  }

  /// Resetea el estado del formulario
  void reset() {
    state = const HonorRegistrationState();
  }
}

/// Provider para el notifier de registro de especialidades
final honorRegistrationNotifierProvider =
    NotifierProvider.autoDispose<HonorRegistrationNotifier, HonorRegistrationState>(() {
  return HonorRegistrationNotifier();
});

/// Provider para verificar si el usuario ya tiene registrada una especialidad
final userHonorForHonorProvider =
    FutureProvider.autoDispose.family<UserHonor?, int>((ref, honorId) async {
  final userHonorsAsync = ref.watch(userHonorsProvider);
  return userHonorsAsync.when(
    data: (honors) {
      try {
        return honors.firstWhere((h) => h.honorId == honorId);
      } catch (_) {
        return null;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// ── Search & filter providers ─────────────────────────────────────────────

/// Search query for the catalog view. Debounce is handled in the UI.
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Currently selected category ID for catalog filtering. null = "Todas".
final selectedCategoryProvider = StateProvider.autoDispose<int?>((ref) => null);

/// All honors filtered by search query and selected category.
/// Used by the redesigned honors_catalog_view.
final filteredHonorsProvider =
    FutureProvider.autoDispose<List<Honor>>((ref) async {
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final categoryId = ref.watch(selectedCategoryProvider);

  // Fetch all honors (no filter params = get all)
  final getHonors = ref.read(getHonorsProvider);
  final result = await getHonors(GetHonorsParams(categoryId: categoryId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (honors) {
      if (query.length < 2) return honors;
      return honors
          .where((h) => h.name.toLowerCase().contains(query))
          .toList();
    },
  );
});

/// Combines catalog honors with user honors to determine display status.
/// Returns a list of tuples: (Honor, UserHonor?) for rendering cards.
final honorsWithStatusProvider =
    FutureProvider.autoDispose<List<({Honor honor, UserHonor? userHonor})>>(
        (ref) async {
  final honorsAsync = await ref.watch(filteredHonorsProvider.future);
  final userHonorsAsync = ref.watch(userHonorsProvider);

  final userHonors = userHonorsAsync.maybeWhen(
    data: (list) => list,
    orElse: () => <UserHonor>[],
  );

  return honorsAsync.map((honor) {
    final uh = userHonors.cast<UserHonor?>().firstWhere(
          (u) => u!.honorId == honor.id,
          orElse: () => null,
        );
    return (honor: honor, userHonor: uh);
  }).toList();
});

// ── Requirements providers ─────────────────────────────────────────────────

/// Provider para el caso de uso de obtener requisitos de una especialidad
final getHonorRequirementsProvider = Provider<GetHonorRequirements>((ref) {
  return GetHonorRequirements(ref.read(honorsRepositoryProvider));
});

/// Provider para el caso de uso de obtener progreso de requisitos del usuario
final getUserHonorProgressProvider = Provider<GetUserHonorProgress>((ref) {
  return GetUserHonorProgress(ref.read(honorsRepositoryProvider));
});

/// Provider para el caso de uso de actualizar progreso de requisitos en batch
final updateRequirementProgressProvider =
    Provider<UpdateRequirementProgress>((ref) {
  return UpdateRequirementProgress(ref.read(honorsRepositoryProvider));
});

/// Provider para los requisitos del catálogo de una especialidad.
/// Keyed by honorId.
final honorRequirementsProvider = FutureProvider.autoDispose
    .family<List<HonorRequirement>, int>((ref, honorId) async {
  final useCase = ref.read(getHonorRequirementsProvider);
  final result =
      await useCase(GetHonorRequirementsParams(honorId: honorId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (requirements) => requirements,
  );
});

/// Parámetros para [userHonorProgressProvider].
/// Encapsula userId + honorId como clave del family.
class UserHonorProgressParams {
  final String userId;
  final int honorId;

  const UserHonorProgressParams({
    required this.userId,
    required this.honorId,
  });

  @override
  bool operator ==(Object other) =>
      other is UserHonorProgressParams &&
      other.userId == userId &&
      other.honorId == honorId;

  @override
  int get hashCode => Object.hash(userId, honorId);
}

/// Provider para el progreso del usuario en los requisitos de una especialidad.
/// Keyed by [UserHonorProgressParams].
final userHonorProgressProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, UserHonorProgressParams>(
        (ref, params) async {
  final useCase = ref.read(getUserHonorProgressProvider);
  final result = await useCase(GetUserHonorProgressParams(
    userId: params.userId,
    honorId: params.honorId,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (progress) => progress,
  );
});

// ── RequirementProgressNotifier ────────────────────────────────────────────

/// Notifier para manejar actualizaciones de progreso de requisitos.
///
/// Recibe [UserHonorProgressParams] como argumento para saber qué
/// proveedor de progreso invalidar tras una actualización exitosa.
class RequirementProgressNotifier
    extends AutoDisposeAsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async => null;

  /// Alterna el estado completado de un requisito individual y sincroniza
  /// con el backend via bulkUpdate de un solo ítem.
  Future<bool> toggle({
    required UserHonorProgressParams progressParams,
    required int requirementId,
    required bool completed,
    String? notes,
  }) async {
    return bulkUpdate(
      progressParams: progressParams,
      updates: [
        {
          'requirementId': requirementId,
          'completed': completed,
          if (notes != null) 'notes': notes,
        }
      ],
    );
  }

  /// Actualiza el progreso de múltiples requisitos en una sola operación
  /// e invalida [userHonorProgressProvider] en caso de éxito.
  Future<bool> bulkUpdate({
    required UserHonorProgressParams progressParams,
    required List<Map<String, dynamic>> updates,
  }) async {
    state = const AsyncValue.loading();

    final authState = ref.read(authNotifierProvider);
    final userId = authState.value?.id;
    if (userId == null) {
      state = AsyncValue.error(
          'Usuario no autenticado', StackTrace.current);
      return false;
    }

    final result = await ref.read(updateRequirementProgressProvider)(
      UpdateRequirementProgressParams(
        userId: userId,
        honorId: progressParams.honorId,
        updates: updates,
      ),
    );

    return result.fold(
      (failure) {
        state =
            AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (updated) {
        state = AsyncValue.data(updated);
        ref.invalidate(
            userHonorProgressProvider(progressParams));
        return true;
      },
    );
  }
}

/// Provider para [RequirementProgressNotifier].
/// Es autoDispose para que se limpie al salir de la pantalla de requisitos.
final requirementProgressNotifierProvider = AsyncNotifierProvider.autoDispose<
    RequirementProgressNotifier, Map<String, dynamic>?>(() {
  return RequirementProgressNotifier();
});
