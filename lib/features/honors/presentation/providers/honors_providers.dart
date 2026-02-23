import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/honors_remote_data_source.dart';
import '../../data/repositories/honors_repository_impl.dart';
import '../../domain/entities/honor.dart';
import '../../domain/entities/honor_category.dart';
import '../../domain/entities/user_honor.dart';
import '../../domain/repositories/honors_repository.dart';
import '../../domain/usecases/get_honor_categories.dart';
import '../../domain/usecases/get_honors.dart';
import '../../domain/usecases/get_user_honors.dart';
import '../../domain/usecases/start_honor.dart';

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

/// Provider para las especialidades de un usuario
final userHonorsProvider = FutureProvider.autoDispose<List<UserHonor>>((ref) async {
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
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
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

/// State notifier para manejar inscripciones en especialidades
class HonorEnrollmentNotifier extends StateNotifier<AsyncValue<UserHonor?>> {
  final StartHonor startHonor;

  HonorEnrollmentNotifier(this.startHonor) : super(const AsyncValue.data(null));

  /// Inscribir a un usuario en una especialidad
  Future<void> enrollInHonor(String userId, int honorId) async {
    state = const AsyncValue.loading();

    final result = await startHonor(
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
    StateNotifierProvider<HonorEnrollmentNotifier, AsyncValue<UserHonor?>>((ref) {
  return HonorEnrollmentNotifier(ref.read(startHonorProvider));
});
