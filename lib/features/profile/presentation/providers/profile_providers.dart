import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_user_profile.dart';
import '../../domain/usecases/update_user_profile.dart';

/// Provider para la fuente de datos remota del perfil
final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);

  return ProfileRemoteDataSourceImpl(
    dio: dio,
    baseUrl: baseUrl,
  );
});

/// Provider para el repositorio del perfil
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final networkInfo = ref.read(networkInfoProvider);
  final remoteDataSource = ref.read(profileRemoteDataSourceProvider);

  return ProfileRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

/// Provider para el caso de uso de obtener perfil de usuario
final getUserProfileProvider = Provider<GetUserProfile>((ref) {
  return GetUserProfile(ref.read(profileRepositoryProvider));
});

/// Provider para el caso de uso de actualizar perfil de usuario
final updateUserProfileProvider = Provider<UpdateUserProfile>((ref) {
  return UpdateUserProfile(ref.read(profileRepositoryProvider));
});

/// Notifier para manejar el perfil del usuario
class ProfileNotifier extends AutoDisposeAsyncNotifier<UserDetail?> {
  CancelToken _cancelToken = CancelToken();

  @override
  Future<UserDetail?> build() async {
    // Crear un nuevo token para este ciclo de vida y cancelarlo al hacer dispose.
    _cancelToken = CancelToken();
    ref.onDispose(() => _cancelToken.cancel());

    // Solo reaccionar a cambios en el ID del usuario (evita cascadas por cambios de metadata).
    final userId = await ref.watch(
      authNotifierProvider.selectAsync((user) => user?.id),
    );
    if (userId == null) return null;

    // Obtener el perfil completo del usuario
    final result = await ref.read(getUserProfileProvider)(
      GetUserProfileParams(userId: userId),
      cancelToken: _cancelToken,
    );

    return result.fold(
      (failure) => null,
      (profile) => profile,
    );
  }

  /// Actualizar el perfil del usuario
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final currentProfile = state.value;
    if (currentProfile == null) {
      return false;
    }

    state = const AsyncValue.loading();

    final result = await ref.read(updateUserProfileProvider)(
      UpdateUserProfileParams(
        userId: currentProfile.id,
        data: data,
      ),
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (updatedProfile) {
        state = AsyncValue.data(updatedProfile);
        return true;
      },
    );
  }

  /// Recargar el perfil del usuario
  Future<void> refresh() async {
    final user = await ref.read(authNotifierProvider.future);

    if (user == null) {
      state = AsyncValue.error(
        'No hay usuario autenticado',
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();

    final result = await ref.read(getUserProfileProvider)(
      GetUserProfileParams(userId: user.id),
      cancelToken: _cancelToken,
    );

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (profile) => AsyncValue.data(profile),
    );
  }
}

/// Provider para el notifier del perfil
final profileNotifierProvider =
    AsyncNotifierProvider.autoDispose<ProfileNotifier, UserDetail?>(() {
  return ProfileNotifier();
});
