import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/post_registration_remote_data_source.dart';
import '../../data/repositories/post_registration_repository_impl.dart';
import '../../domain/entities/completion_status.dart';
import '../../domain/repositories/post_registration_repository.dart';

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

/// Provider para el estado de completitud del post-registro
final completionStatusProvider =
    AsyncNotifierProvider.autoDispose<CompletionStatusNotifier, CompletionStatus?>(() {
  return CompletionStatusNotifier();
});

/// Notifier para el estado de completitud del post-registro
class CompletionStatusNotifier extends AutoDisposeAsyncNotifier<CompletionStatus?> {
  @override
  Future<CompletionStatus?> build() async {
    final result =
        await ref.read(postRegistrationRepositoryProvider).getCompletionStatus();
    return result.fold(
      (failure) => null,
      (status) => status,
    );
  }

  /// Recargar el estado de completitud
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final result =
        await ref.read(postRegistrationRepositoryProvider).getCompletionStatus();
    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (status) => AsyncValue.data(status),
    );
  }
}

/// Provider para el paso actual del post-registro
final currentStepProvider = StateProvider.autoDispose<int>((ref) => 1);

/// Provider para la foto de perfil temporal (path local)
final selectedPhotoPathProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Provider para indicar si se está subiendo la foto
final isUploadingPhotoProvider = StateProvider.autoDispose<bool>((ref) => false);
