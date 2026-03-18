import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/classes_remote_data_source.dart';
import '../../data/repositories/classes_repository_impl.dart';
import '../../domain/entities/progressive_class.dart';
import '../../domain/entities/class_module.dart';
import '../../domain/entities/class_progress.dart';
import '../../domain/entities/class_with_progress.dart';
import '../../domain/repositories/classes_repository.dart';
import '../../domain/usecases/get_user_classes.dart';
import '../../domain/usecases/get_class_detail.dart';
import '../../domain/usecases/get_class_modules.dart';
import '../../domain/usecases/update_class_progress.dart';
import '../../domain/usecases/get_class_with_progress.dart';
import '../../domain/usecases/submit_requirement.dart';
import '../../domain/usecases/upload_requirement_file.dart';
import '../../domain/usecases/delete_requirement_file.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Provider para el data source remoto de clases
final classesRemoteDataSourceProvider =
    Provider<ClassesRemoteDataSource>((ref) {
  return ClassesRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

/// Provider para el repositorio de clases
final classesRepositoryProvider = Provider<ClassesRepository>((ref) {
  return ClassesRepositoryImpl(
    remoteDataSource: ref.read(classesRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Use case providers ────────────────────────────────────────────────────────

final getUserClassesProvider = Provider<GetUserClasses>((ref) {
  return GetUserClasses(ref.read(classesRepositoryProvider));
});

final getClassDetailProvider = Provider<GetClassDetail>((ref) {
  return GetClassDetail(ref.read(classesRepositoryProvider));
});

final getClassModulesProvider = Provider<GetClassModules>((ref) {
  return GetClassModules(ref.read(classesRepositoryProvider));
});

final updateClassProgressProvider = Provider<UpdateClassProgress>((ref) {
  return UpdateClassProgress(ref.read(classesRepositoryProvider));
});

final getClassWithProgressUseCaseProvider =
    Provider<GetClassWithProgress>((ref) {
  return GetClassWithProgress(ref.read(classesRepositoryProvider));
});

final submitRequirementUseCaseProvider = Provider<SubmitRequirement>((ref) {
  return SubmitRequirement(ref.read(classesRepositoryProvider));
});

final uploadRequirementFileUseCaseProvider =
    Provider<UploadRequirementFile>((ref) {
  return UploadRequirementFile(ref.read(classesRepositoryProvider));
});

final deleteRequirementFileUseCaseProvider =
    Provider<DeleteRequirementFile>((ref) {
  return DeleteRequirementFile(ref.read(classesRepositoryProvider));
});

// ── Data providers ────────────────────────────────────────────────────────────

/// Provider para las clases de un usuario.
final userClassesProvider =
    FutureProvider.autoDispose<List<ProgressiveClass>>((ref) async {
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

/// Provider para el detalle de una clase especifica.
final classDetailProvider =
    FutureProvider.autoDispose.family<ProgressiveClass, int>(
        (ref, classId) async {
  final getClassDetail = ref.read(getClassDetailProvider);
  final result = await getClassDetail(GetClassDetailParams(classId: classId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (progressiveClass) => progressiveClass,
  );
});

/// Provider para los modulos de una clase especifica.
final classModulesProvider =
    FutureProvider.autoDispose.family<List<ClassModule>, int>(
        (ref, classId) async {
  final getClassModules = ref.read(getClassModulesProvider);
  final result =
      await getClassModules(GetClassModulesParams(classId: classId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (modules) => modules,
  );
});

/// Provider para la clase con progreso detallado.
///
/// autoDispose para liberar memoria al salir de la pantalla.
final classWithProgressProvider = FutureProvider.autoDispose
    .family<ClassWithProgress, int>((ref, classId) async {
  final authState = ref.watch(authNotifierProvider);
  final userId = authState.value?.id;

  if (userId == null) {
    throw Exception('Usuario no autenticado');
  }

  final useCase = ref.read(getClassWithProgressUseCaseProvider);
  final result = await useCase(
    GetClassWithProgressParams(userId: userId, classId: classId),
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (classWithProgress) => classWithProgress,
  );
});

// ── Requirement operations state ──────────────────────────────────────────────

/// Estado para operaciones de requerimiento (submit, upload, delete).
class RequirementOperationState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const RequirementOperationState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  RequirementOperationState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return RequirementOperationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

/// Notifier para gestionar el estado de un requerimiento activo.
///
/// Maneja operaciones de subida de archivos, eliminacion y envio a validacion.
/// Al completar con exito cualquier mutacion, invalida [classWithProgressProvider]
/// para refrescar datos frescos del backend.
class RequirementNotifier
    extends AutoDisposeFamilyNotifier<RequirementOperationState, int> {
  @override
  RequirementOperationState build(int classId) =>
      const RequirementOperationState();

  String get _userId {
    final authState = ref.read(authNotifierProvider);
    return authState.value?.id ?? '';
  }

  int get _classId => arg;

  /// Envia un requerimiento a validacion (pendiente -> enviado).
  Future<bool> submit(int requirementId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref.read(submitRequirementUseCaseProvider)(
      SubmitRequirementParams(
        userId: _userId,
        classId: _classId,
        requirementId: requirementId,
      ),
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
        ref.invalidate(classWithProgressProvider(_classId));
        return true;
      },
    );
  }

  /// Sube un archivo de evidencia al requerimiento indicado.
  ///
  /// [pickedFile] proviene de [ImagePicker] o [FilePicker].
  Future<bool> uploadFile({
    required int requirementId,
    required XFile pickedFile,
    required String mimeType,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref.read(uploadRequirementFileUseCaseProvider)(
      UploadRequirementFileParams(
        userId: _userId,
        classId: _classId,
        requirementId: requirementId,
        filePath: pickedFile.path,
        fileName: pickedFile.name,
        mimeType: mimeType,
      ),
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
        ref.invalidate(classWithProgressProvider(_classId));
        return true;
      },
    );
  }

  /// Elimina un archivo de evidencia.
  Future<bool> deleteFile({
    required int requirementId,
    required String fileId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    final result = await ref.read(deleteRequirementFileUseCaseProvider)(
      DeleteRequirementFileParams(
        userId: _userId,
        classId: _classId,
        requirementId: requirementId,
        fileId: fileId,
      ),
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
        ref.invalidate(classWithProgressProvider(_classId));
        return true;
      },
    );
  }

  /// Limpia el estado de error / exito.
  void reset() => state = const RequirementOperationState();
}

/// Provider para el notifier de operaciones de requerimiento.
///
/// Es un family por [classId] para que cada clase tenga su propio estado.
/// Resuelve el userId internamente desde el authNotifier.
final requirementNotifierProvider = NotifierProvider.autoDispose
    .family<RequirementNotifier, RequirementOperationState, int>(
  RequirementNotifier.new,
);

// ── Class progress notifier (legacy) ──────────────────────────────────────────

/// Notifier para manejar actualizaciones de progreso
class ClassProgressNotifier extends AsyncNotifier<ClassProgress?> {
  @override
  Future<ClassProgress?> build() async => null;

  /// Actualizar progreso de una seccion
  Future<void> updateProgress(
    String userId,
    int classId,
    Map<String, dynamic> progressData,
  ) async {
    state = const AsyncValue.loading();

    final result = await ref.read(updateClassProgressProvider)(
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
    AsyncNotifierProvider<ClassProgressNotifier, ClassProgress?>(() {
  return ClassProgressNotifier();
});
