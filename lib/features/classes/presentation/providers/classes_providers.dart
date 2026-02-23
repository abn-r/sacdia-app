import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/classes_remote_data_source.dart';
import '../../data/repositories/classes_repository_impl.dart';
import '../../domain/entities/progressive_class.dart';
import '../../domain/entities/class_module.dart';
import '../../domain/entities/class_progress.dart';
import '../../domain/repositories/classes_repository.dart';
import '../../domain/usecases/get_user_classes.dart';
import '../../domain/usecases/get_class_detail.dart';
import '../../domain/usecases/get_class_modules.dart';
import '../../domain/usecases/update_class_progress.dart';

/// Provider para el data source remoto de clases
final classesRemoteDataSourceProvider = Provider<ClassesRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);

  return ClassesRemoteDataSourceImpl(
    dio: dio,
    baseUrl: baseUrl,
  );
});

/// Provider para el repositorio de clases
final classesRepositoryProvider = Provider<ClassesRepository>((ref) {
  final remoteDataSource = ref.read(classesRemoteDataSourceProvider);
  final networkInfo = ref.read(networkInfoProvider);

  return ClassesRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

/// Provider para el caso de uso de obtener clases de usuario
final getUserClassesProvider = Provider<GetUserClasses>((ref) {
  return GetUserClasses(ref.read(classesRepositoryProvider));
});

/// Provider para el caso de uso de obtener detalle de clase
final getClassDetailProvider = Provider<GetClassDetail>((ref) {
  return GetClassDetail(ref.read(classesRepositoryProvider));
});

/// Provider para el caso de uso de obtener módulos de clase
final getClassModulesProvider = Provider<GetClassModules>((ref) {
  return GetClassModules(ref.read(classesRepositoryProvider));
});

/// Provider para el caso de uso de actualizar progreso de clase
final updateClassProgressProvider = Provider<UpdateClassProgress>((ref) {
  return UpdateClassProgress(ref.read(classesRepositoryProvider));
});

/// Provider para las clases de un usuario
final userClassesProvider = FutureProvider.autoDispose<List<ProgressiveClass>>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  final userId = authState.value?.id;

  if (userId == null) {
    throw Exception('Usuario no autenticado');
  }

  final getUserClasses = ref.read(getUserClassesProvider);
  final result = await getUserClasses(GetUserClassesParams(userId: userId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (classes) => classes,
  );
});

/// Provider para el detalle de una clase específica
final classDetailProvider =
    FutureProvider.autoDispose.family<ProgressiveClass, int>((ref, classId) async {
  final getClassDetail = ref.read(getClassDetailProvider);
  final result = await getClassDetail(GetClassDetailParams(classId: classId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (progressiveClass) => progressiveClass,
  );
});

/// Provider para los módulos de una clase específica
final classModulesProvider =
    FutureProvider.autoDispose.family<List<ClassModule>, int>((ref, classId) async {
  final getClassModules = ref.read(getClassModulesProvider);
  final result = await getClassModules(GetClassModulesParams(classId: classId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (modules) => modules,
  );
});

/// State notifier para manejar actualizaciones de progreso
class ClassProgressNotifier extends StateNotifier<AsyncValue<ClassProgress?>> {
  final UpdateClassProgress updateClassProgress;

  ClassProgressNotifier(this.updateClassProgress) : super(const AsyncValue.data(null));

  /// Actualizar progreso de una sección
  Future<void> updateProgress(
    String userId,
    int classId,
    Map<String, dynamic> progressData,
  ) async {
    state = const AsyncValue.loading();

    final result = await updateClassProgress(
      UpdateClassProgressParams(
        userId: userId,
        classId: classId,
        progressData: progressData,
      ),
    );

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (progress) => AsyncValue.data(progress),
    );
  }
}

/// Provider para el notifier de progreso de clase
final classProgressNotifierProvider =
    StateNotifierProvider<ClassProgressNotifier, AsyncValue<ClassProgress?>>((ref) {
  return ClassProgressNotifier(ref.read(updateClassProgressProvider));
});
