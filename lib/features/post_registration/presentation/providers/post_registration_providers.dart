import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/post_registration_remote_data_source.dart';
import '../../data/repositories/post_registration_repository_impl.dart';
import '../../domain/entities/completion_status.dart';
import '../../domain/repositories/post_registration_repository.dart';
import '../../domain/usecases/upload_profile_picture.dart';

/// Provider para el repositorio de post-registro
final postRegistrationRepositoryProvider =
    Provider.autoDispose<PostRegistrationRepository>((ref) {
  final dio = ref.read(dioProvider);
  final networkInfo = ref.read(networkInfoProvider);

  return PostRegistrationRepositoryImpl(
    remoteDataSource: PostRegistrationRemoteDataSourceImpl(
      dio: dio,
      baseUrl: AppConstants.baseUrl,
    ),
    networkInfo: networkInfo,
  );
});

/// Provider para el caso de uso de subir foto de perfil.
final uploadProfilePictureProvider =
    Provider.autoDispose<UploadProfilePicture>((ref) {
  return UploadProfilePicture(ref.read(postRegistrationRepositoryProvider));
});

/// Notifier para subir foto de perfil sin acoplar vistas al repositorio.
class ProfilePhotoUploadNotifier extends AutoDisposeAsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<bool> upload({
    required String userId,
    required String filePath,
  }) async {
    ref.read(isUploadingPhotoProvider.notifier).state = true;
    state = const AsyncValue.loading();

    final result = await ref.read(uploadProfilePictureProvider)(
      UploadProfilePictureParams(userId: userId, filePath: filePath),
    );

    ref.read(isUploadingPhotoProvider.notifier).state = false;

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (url) {
        state = AsyncValue.data(url);
        return true;
      },
    );
  }
}

/// Provider para upload de foto de perfil.
final profilePhotoUploadNotifierProvider =
    AsyncNotifierProvider.autoDispose<ProfilePhotoUploadNotifier, String?>(
  ProfilePhotoUploadNotifier.new,
);

/// Provider para el estado de completitud del post-registro
final completionStatusProvider = AsyncNotifierProvider.autoDispose<
    CompletionStatusNotifier, CompletionStatus?>(() {
  return CompletionStatusNotifier();
});

/// Notifier para el estado de completitud del post-registro
class CompletionStatusNotifier
    extends AutoDisposeAsyncNotifier<CompletionStatus?> {
  @override
  Future<CompletionStatus?> build() async {
    ref.keepAlive();
    final cancelToken = CancelToken();
    ref.onDispose(() => cancelToken.cancel());
    final result = await ref
        .read(postRegistrationRepositoryProvider)
        .getCompletionStatus(cancelToken: cancelToken);
    return result.fold(
      (failure) => null,
      (status) => status,
    );
  }

  /// Recargar el estado de completitud
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final result = await ref
        .read(postRegistrationRepositoryProvider)
        .getCompletionStatus();
    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (status) => AsyncValue.data(status),
    );
  }
}

/// Provider para el paso actual del post-registro
final currentStepProvider = StateProvider.autoDispose<int>((ref) => 1);

/// Provider para la foto de perfil temporal (path local)
final selectedPhotoPathProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Provider para indicar si se está subiendo la foto
final isUploadingPhotoProvider =
    StateProvider.autoDispose<bool>((ref) => false);
