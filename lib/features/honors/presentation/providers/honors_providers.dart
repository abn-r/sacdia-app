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
import '../../domain/entities/user_honor_requirement_progress.dart';
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
  // Fix 1: use selectAsync to avoid watching the full auth state object.
  // This provider only rebuilds when the userId itself changes, not on every
  // auth state field update.
  final userId = await ref.watch(
    authNotifierProvider.selectAsync((user) => user?.id),
  );

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

/// Provider para estadísticas de especialidades del usuario derivadas localmente.
///
/// Computes stats synchronously from [userHonorsProvider] — no extra API call.
/// Returns an [AsyncValue<Map<String, dynamic>>] with the same shape used
/// across the app:
///   - 'total'       : total user honors
///   - 'validated'   : count with validationStatus == 'APPROVED'
///   - 'completed'   : alias for 'validated' (used by my_honors_view)
///   - 'in_progress' : count not yet APPROVED
final userHonorStatsLocalProvider =
    Provider<AsyncValue<Map<String, dynamic>>>((ref) {
  final userHonorsAsync = ref.watch(userHonorsProvider);

  return userHonorsAsync.whenData((honors) {
    final total = honors.length;
    final validated = honors.where((h) => h.isCompleted).length;
    final inProgress = total - validated;

    return {
      'total': total,
      'validated': validated,
      'completed': validated,
      'in_progress': inProgress,
    };
  });
});

/// Provider para estadísticas de especialidades del usuario (API call)
final userHonorStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // Fix 1: use selectAsync — rebuilds only when userId changes.
  final userId = await ref.watch(
    authNotifierProvider.selectAsync((user) => user?.id),
  );

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

/// Provider para verificar si el usuario ya tiene registrada una especialidad.
///
/// Plain [Provider] — synchronous derivation of [userHonorsProvider].
/// Returns null while [userHonorsProvider] is still loading (no enrollment
/// data yet), which is the correct default: show the "not enrolled" state
/// until the list resolves. Consumers that need to distinguish "loading" from
/// "not enrolled" should also watch [userHonorsProvider] directly.
final userHonorForHonorProvider =
    Provider.autoDispose.family<UserHonor?, int>((ref, honorId) {
  return ref.watch(userHonorsProvider).valueOrNull
      ?.where((h) => h.honorId == honorId)
      .firstOrNull;
});

// ── Search & filter providers ─────────────────────────────────────────────

/// Search query for the catalog view. Debounce is handled in the UI.
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Currently selected category ID for catalog filtering. null = "Todas".
final selectedCategoryProvider = StateProvider.autoDispose<int?>((ref) => null);

/// Fix 2: fetches ALL honors ONCE from the network and caches the result.
/// Category filtering and text search are done locally in [filteredHonorsProvider].
/// Consumers that need a network refresh should invalidate this provider directly.
///
/// Not autoDispose so it survives tab switches in the catalog without re-fetching.
final allHonorsProvider = FutureProvider<List<Honor>>((ref) async {
  final getHonors = ref.read(getHonorsProvider);
  final result = await getHonors(const GetHonorsParams());

  return result.fold(
    (failure) => throw Exception(failure.message),
    (honors) => honors,
  );
});

/// All honors filtered by search query and selected category.
/// Used by the redesigned honors_catalog_view.
///
/// Fix 2: now a [Provider] (synchronous) that derives from [allHonorsProvider].
/// Filter/search changes no longer trigger network requests — they filter the
/// already-fetched list locally. The return type is [AsyncValue<List<Honor>>]
/// so existing consumers that call `.when(data:, loading:, error:)` on the
/// result of `ref.watch(filteredHonorsProvider)` continue to work unchanged.
///
/// NOTE: `ref.invalidate(filteredHonorsProvider)` in the catalog view resets
/// only the local filter computation. To also refetch from the network, also
/// call `ref.invalidate(allHonorsProvider)`.
final filteredHonorsProvider =
    Provider.autoDispose<AsyncValue<List<Honor>>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final categoryId = ref.watch(selectedCategoryProvider);
  final allHonorsAsync = ref.watch(allHonorsProvider);

  return allHonorsAsync.whenData((honors) {
    // Category filter
    final byCategory = categoryId == null
        ? honors
        : honors.where((h) => h.categoryId == categoryId).toList();

    // Text search — only applied when query is at least 2 chars
    if (query.length < 2) return byCategory;
    return byCategory
        .where((h) => h.name.toLowerCase().contains(query))
        .toList();
  });
});

/// Combines catalog honors with user honors to determine display status.
/// Returns a list of tuples: (Honor, UserHonor?) for rendering cards.
final honorsWithStatusProvider =
    FutureProvider.autoDispose<List<({Honor honor, UserHonor? userHonor})>>(
        (ref) async {
  // filteredHonorsProvider is a Provider<AsyncValue<List<Honor>>>, a
  // synchronous derivation of allHonorsProvider. We await allHonorsProvider
  // first so this FutureProvider stays in loading state while the network
  // request is in flight, then apply the in-memory filter from
  // filteredHonorsProvider (which is already computed at this point).
  await ref.watch(allHonorsProvider.future);

  // At this point allHonorsProvider has resolved, so filteredHonorsProvider
  // is guaranteed to hold AsyncValue.data. If it somehow carries an error
  // (shouldn't happen, but defensive), re-throw it.
  final filteredAsync = ref.watch(filteredHonorsProvider);
  final honors = filteredAsync.when(
    data: (list) => list,
    loading: () => <Honor>[],       // unreachable after awaiting allHonors
    error: (err, st) => throw err,
  );

  // Fix 3: await the future so we never flash an empty list while
  // userHonorsProvider is still loading.
  final userHonors = await ref.watch(userHonorsProvider.future);

  return honors.map((honor) {
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
  final result = await useCase(GetHonorRequirementsParams(honorId: honorId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (requirements) => requirements,
  );
});

/// Provider para el progreso del usuario en los requisitos de una especialidad.
/// Keyed by honorId — el userId lo deriva el backend del JWT.
///
/// Nota: no es autoDispose para que el catálogo pueda leer el progreso de los
/// honors inscritos sin re-fetchear al cambiar de pestaña.
final userHonorProgressProvider = FutureProvider
    .family<List<UserHonorRequirementProgress>, int>((ref, honorId) async {
  final useCase = ref.read(getUserHonorProgressProvider);
  final result = await useCase(GetUserHonorProgressParams(honorId: honorId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (progress) => progress,
  );
});

/// Provider derivado que computa stats de progreso a partir de [userHonorProgressProvider].
///
/// Retorna un record con: total, completed, percentage.
/// Es un [Provider] síncrono que reactivamente recalcula cuando cambia el progreso.
final honorProgressStatsProvider = Provider.family<
    ({int total, int completed, double percentage}),
    int>((ref, honorId) {
  final progressAsync = ref.watch(userHonorProgressProvider(honorId));

  return progressAsync.maybeWhen(
    data: (list) {
      final total = list.length;
      final completed = list.where((p) => p.completed).length;
      final percentage = total > 0 ? completed / total : 0.0;
      return (total: total, completed: completed, percentage: percentage);
    },
    orElse: () => (total: 0, completed: 0, percentage: 0.0),
  );
});

// ── RequirementProgressNotifier ────────────────────────────────────────────

/// Notifier para manejar actualizaciones de progreso de requisitos.
///
/// Keyed por honorId para invalidar el provider de progreso correcto.
class RequirementProgressNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<UserHonorRequirementProgress>?, int> {
  @override
  Future<List<UserHonorRequirementProgress>?> build(int arg) async => null;

  /// Actualiza el progreso de múltiples requisitos en una sola operación.
  /// Invalida [userHonorProgressProvider] en caso de éxito.
  Future<bool> bulkUpdate(List<Map<String, dynamic>> updates) async {
    state = const AsyncValue.loading();

    final result = await ref.read(updateRequirementProgressProvider)(
      UpdateRequirementProgressParams(
        honorId: arg,
        updates: updates,
      ),
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (updated) {
        state = AsyncValue.data(updated);
        ref.invalidate(userHonorProgressProvider(arg));
        return true;
      },
    );
  }
}

/// Provider para [RequirementProgressNotifier].
/// Es autoDispose.family keyed por honorId.
final requirementProgressNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<RequirementProgressNotifier, List<UserHonorRequirementProgress>?,
        int>(() {
  return RequirementProgressNotifier();
});
