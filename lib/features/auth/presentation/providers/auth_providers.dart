import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../providers/storage_provider.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/switch_context.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../providers/dio_provider.dart';

/// Provider para la URL base de la API
final apiBaseUrlProvider = Provider((ref) {
  return AppConstants.baseUrl;
});

/// Provider para el repositorio de autenticación
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final networkInfo = ref.read(networkInfoProvider);
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);

  return AuthRepositoryImpl(
    remoteDataSource: AuthRemoteDataSourceImpl(
      dio: dio,
      baseUrl: baseUrl,
    ),
    networkInfo: networkInfo,
  );
});

/// Provider para el caso de uso de obtener el usuario actual
final getCurrentUserProvider = Provider<GetCurrentUser>((ref) {
  return GetCurrentUser(ref.read(authRepositoryProvider));
});

/// Provider para el caso de uso de iniciar sesión
final signInProvider = Provider<SignIn>((ref) {
  return SignIn(ref.read(authRepositoryProvider));
});

/// Provider para el caso de uso de registro
final signUpProvider = Provider<SignUp>((ref) {
  return SignUp(ref.read(authRepositoryProvider));
});

/// Provider para el caso de uso de cerrar sesión
final signOutProvider = Provider<SignOut>((ref) {
  return SignOut(ref.read(authRepositoryProvider));
});

/// Provider para el caso de uso de cambio de contexto
final switchContextProvider = Provider<SwitchContext>((ref) {
  return SwitchContext(ref.read(authRepositoryProvider));
});

/// Flag global para rastrear manualmente el estado de autenticación
final isUserLoggedOutProvider = StateProvider<bool>((ref) => false);

/// Provider para el stream de estado de autenticación con verificación manual adicional
final authStateProvider = StreamProvider<bool>((ref) {
  final manuallyLoggedOut = ref.watch(isUserLoggedOutProvider);

  if (manuallyLoggedOut) {
    return Stream.value(false);
  }

  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Notifier para manejar la autenticación y sus estados
class AuthNotifier extends AsyncNotifier<UserEntity?> {
  static const _tag = 'AuthNotifier';

  @override
  Future<UserEntity?> build() async {
    final repository = ref.read(authRepositoryProvider);

    AppLogger.i('Verificando token local', tag: _tag);
    final hasToken = await repository.hasLocalToken();

    if (!hasToken) {
      AppLogger.i('Sin token local, redirigiendo a login', tag: _tag);
      return null;
    }

    AppLogger.i('Token encontrado, validando con /auth/me', tag: _tag);
    final result = await ref.read(getCurrentUserProvider)(NoParams());

    return result.fold(
      (failure) {
        if (failure is NetworkFailure || failure is ServerFailure) {
          AppLogger.w('Sin conectividad, intentando caché', tag: _tag);
          final prefs = ref.read(sharedPreferencesProvider);
          final cachedId = prefs.getString('cached_user_id');
          final cachedEmail = prefs.getString('cached_user_email');
          if (cachedId != null && cachedEmail != null) {
            AppLogger.i('Sesión restaurada desde caché: $cachedEmail',
                tag: _tag);
            return UserEntity(
              id: cachedId,
              email: cachedEmail,
              name: prefs.getString('cached_user_name'),
              postRegisterComplete:
                  prefs.getBool('cached_post_register_complete') ?? false,
            );
          }
          AppLogger.i('Sin caché, redirigiendo a login', tag: _tag);
          return null;
        }
        AppLogger.e('Error al validar token: ${failure.message}', tag: _tag);
        return null;
      },
      (user) {
        if (user != null) {
          AppLogger.i('Usuario autenticado: ${user.email}', tag: _tag);
          _cacheUser(user);
          return user;
        }
        AppLogger.w('Servidor respondió sin usuario, intentando caché',
            tag: _tag);
        final prefs = ref.read(sharedPreferencesProvider);
        final cachedId = prefs.getString('cached_user_id');
        final cachedEmail = prefs.getString('cached_user_email');
        if (cachedId != null && cachedEmail != null) {
          AppLogger.i('Sesión restaurada desde caché: $cachedEmail', tag: _tag);
          return UserEntity(
            id: cachedId,
            email: cachedEmail,
            name: prefs.getString('cached_user_name'),
            postRegisterComplete:
                prefs.getBool('cached_post_register_complete') ?? false,
          );
        }
        AppLogger.i('Sin caché, redirigiendo a login', tag: _tag);
        return null;
      },
    );
  }

  /// Persiste los datos del usuario en SharedPreferences y SecureStorage para
  /// restauración offline. El flag post_register_complete se escribe en ambos
  /// almacenes para que el datasource pueda leerlo como fallback en /auth/me.
  void _cacheUser(UserEntity user) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString('cached_user_id', user.id);
    prefs.setString('cached_user_email', user.email);
    if (user.name != null) prefs.setString('cached_user_name', user.name!);
    prefs.setBool('cached_post_register_complete', user.postRegisterComplete);
    ref.read(secureStorageProvider).write(
      'cached_post_register_complete',
      user.postRegisterComplete.toString(),
    );
  }

  /// Iniciar sesión con email y contraseña
  Future<bool> signIn({required String email, required String password}) async {
    AppLogger.i('Login iniciado: $email', tag: _tag);
    state = const AsyncValue.loading();

    final result = await ref.read(signInProvider)(
      SignInParams(email: email, password: password),
    );

    state = result.fold(
      (failure) {
        final errorMessage = failure is AuthFailure
            ? failure.message
            : 'Error al iniciar sesión';
        AppLogger.w('Login fallido: $errorMessage', tag: _tag);
        return AsyncValue.error(errorMessage, StackTrace.current);
      },
      (user) {
        AppLogger.i('Login exitoso: ${user.email}', tag: _tag);
        ref.read(isUserLoggedOutProvider.notifier).state = false;
        ref.read(sharedPreferencesProvider).setBool('user_manually_logged_out', false);
        _cacheUser(user);
        return AsyncValue.data(user);
      },
    );

    return !state.hasError;
  }

  /// Registrar un nuevo usuario
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
  }) async {
    state = const AsyncValue.loading();

    final result = await ref.read(signUpProvider)(
      SignUpParams(
        email: email,
        password: password,
        name: name,
        paternalSurname: paternalSurname,
        maternalSurname: maternalSurname,
      ),
    );

    state = result.fold(
      (failure) {
        final errorMessage = failure is AuthFailure
            ? failure.message
            : 'Error al registrar usuario';
        return AsyncValue.error(errorMessage, StackTrace.current);
      },
      (user) => AsyncValue.data(user),
    );

    return !state.hasError;
  }

  /// Marks the current user's post-registration as complete in the in-memory
  /// auth state. Call this after step 3 is successfully saved so the router
  /// redirects correctly without waiting for a full /auth/me refresh.
  void markPostRegisterComplete() {
    final current = state.valueOrNull;
    if (current == null) return;
    final updatedUser = UserEntity(
      id: current.id,
      email: current.email,
      name: current.name,
      avatar: current.avatar,
      metadata: current.metadata,
      authorization: current.authorization,
      lastSignInAt: current.lastSignInAt,
      createdAt: current.createdAt,
      postRegisterComplete: true,
    );
    state = AsyncValue.data(updatedUser);
    _cacheUser(updatedUser);
  }

  /// Cambia el contexto activo de autorización y refresca el estado del usuario.
  ///
  /// Llama al use case SwitchContext, y en caso de éxito vuelve a llamar
  /// getCurrentUser() para propagar el nuevo contexto a todo el árbol de providers.
  /// Retorna true si el cambio fue exitoso, false en caso contrario.
  Future<bool> switchContext(String assignmentId) async {
    AppLogger.i('Cambiando contexto a $assignmentId', tag: _tag);

    final result = await ref.read(switchContextProvider)(
      SwitchContextParams(assignmentId: assignmentId),
    );

    // Extract success/failure synchronously before doing any async work.
    final switchFailed = result.isLeft();
    if (switchFailed) {
      result.fold(
        (failure) => AppLogger.w(
          'Error al cambiar contexto: ${failure.message}',
          tag: _tag,
        ),
        (_) {},
      );
      return false;
    }

    // Switch succeeded — refresh the full user so downstream providers
    // (clubContextProvider, dashboardNotifierProvider, etc.) re-evaluate.
    AppLogger.i('Contexto cambiado. Refrescando usuario...', tag: _tag);
    final refreshResult = await ref.read(getCurrentUserProvider)(NoParams());
    refreshResult.fold(
      (failure) => AppLogger.w(
        'Error al refrescar usuario tras cambio de contexto: ${failure.message}',
        tag: _tag,
      ),
      (user) {
        if (user != null) {
          _cacheUser(user);
          state = AsyncValue.data(user);
        }
      },
    );

    return true;
  }

  /// Cerrar sesión
  Future<bool> signOut() async {
    state = const AsyncValue.loading();

    ref.read(isUserLoggedOutProvider.notifier).state = true;

    final result = await ref.read(signOutProvider)(NoParams());

    return result.fold(
      (failure) {
        final errorMessage =
            failure is AuthFailure ? failure.message : 'Error al cerrar sesión';
        state = AsyncValue.error(errorMessage, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);

        final prefs = ref.read(sharedPreferencesProvider);
        prefs.setBool('user_manually_logged_out', true);
        prefs.remove('cached_user_id');
        prefs.remove('cached_user_email');
        prefs.remove('cached_user_name');
        prefs.remove('cached_post_register_complete');
        ref.read(secureStorageProvider).delete('cached_post_register_complete');

        return true;
      },
    );
  }
}

/// Provider para NetworkInfo
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl();
});

/// Provider para AuthNotifier
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, UserEntity?>(() {
  return AuthNotifier();
});
