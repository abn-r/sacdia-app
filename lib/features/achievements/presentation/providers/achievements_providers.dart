import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/achievements_remote_data_source.dart';
import '../../data/repositories/achievements_repository_impl.dart';
import '../../domain/entities/achievement_category.dart';
import '../../domain/repositories/achievements_repository.dart';

/// Provider para el data source remoto de logros
final achievementsRemoteDataSourceProvider =
    Provider<AchievementsRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);

  return AchievementsRemoteDataSourceImpl(
    dio: dio,
    baseUrl: baseUrl,
  );
});

/// Provider para el repositorio de logros
final achievementsRepositoryProvider = Provider<AchievementsRepository>((ref) {
  final remoteDataSource = ref.read(achievementsRemoteDataSourceProvider);
  final networkInfo = ref.read(networkInfoProvider);

  return AchievementsRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

/// Provider para el catálogo de logros agrupado por categoría.
///
/// autoDispose + keepAlive: sobrevive cambios de pestaña sin re-fetchear.
final achievementsCatalogProvider =
    FutureProvider.autoDispose<List<UserAchievementCategoryGroup>>((ref) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final repository = ref.read(achievementsRepositoryProvider);
  final result = await repository.getAchievements();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (groups) => groups,
  );
});

/// Provider para los logros del usuario con summary de progreso.
///
/// autoDispose + keepAlive: evita re-fetches en cambios de tab.
final userAchievementsProvider =
    FutureProvider.autoDispose<UserAchievementsResponse>((ref) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  // Solo reconstruir cuando cambia el userId (no en cualquier cambio de auth state)
  final userId = await ref.watch(
    authNotifierProvider.selectAsync((user) => user?.id),
  );

  if (userId == null) {
    throw Exception(tr('errors.user_not_authenticated'));
  }

  final repository = ref.read(achievementsRepositoryProvider);
  final result = await repository.getUserAchievements();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (response) => response,
  );
});

/// Provider para la lista de categorías de logros.
///
/// autoDispose + keepAlive: sobrevive cambios de pestaña.
final achievementCategoriesProvider =
    FutureProvider.autoDispose<List<AchievementCategory>>((ref) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final repository = ref.read(achievementsRepositoryProvider);
  final result = await repository.getCategories();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (categories) => categories,
  );
});

/// Provider derivado: categoría seleccionada para el filtro de logros.
/// null = "Todas las categorías"
final selectedAchievementCategoryProvider =
    StateProvider.autoDispose<int?>((ref) => null);

/// Provider derivado: categorías del response de usuario (sin llamada extra)
///
/// Extrae las categorías del [userAchievementsProvider] para usarlas
/// como filtros en la vista, reutilizando la respuesta ya cacheada.
final userAchievementCategoriesProvider =
    Provider.autoDispose<AsyncValue<List<AchievementCategory>>>((ref) {
  final responseAsync = ref.watch(userAchievementsProvider);
  return responseAsync.whenData(
    (response) => response.categories.map((group) => group.category).toList(),
  );
});

/// Provider derivado: summary de logros del usuario.
final userAchievementsSummaryProvider =
    Provider.autoDispose<AsyncValue<UserAchievementsSummary>>((ref) {
  final responseAsync = ref.watch(userAchievementsProvider);
  return responseAsync.whenData((response) => response.summary);
});

/// Provider derivado: categorías filtradas según selección del usuario.
///
/// Retorna [AsyncValue] para que los consumidores manejen loading/error.
final filteredAchievementGroupsProvider =
    Provider.autoDispose<AsyncValue<List<UserAchievementCategoryGroup>>>((ref) {
  final selectedCategory = ref.watch(selectedAchievementCategoryProvider);
  final responseAsync = ref.watch(userAchievementsProvider);

  return responseAsync.whenData((response) {
    if (selectedCategory == null) return response.categories;
    return response.categories
        .where((g) => g.category.categoryId == selectedCategory)
        .toList();
  });
});
