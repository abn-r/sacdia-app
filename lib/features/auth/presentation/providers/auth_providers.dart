import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../providers/storage_provider.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/authorization_snapshot.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_in_with_apple.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/switch_context.dart';
import '../../domain/usecases/update_password.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/notifications/push_notification_provider.dart';
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

  final secureStorage = ref.read(secureStorageProvider);

  return AuthRepositoryImpl(
    remoteDataSource: AuthRemoteDataSourceImpl(
      dio: dio,
      baseUrl: baseUrl,
      secureStorage: secureStorage,
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

/// Provider para el caso de uso de actualización de contraseña
final updatePasswordProvider = Provider<UpdatePassword>((ref) {
  return UpdatePassword(ref.read(authRepositoryProvider));
});

/// Provider para el caso de uso de OAuth con Google
final signInWithGoogleProvider = Provider<SignInWithGoogle>((ref) {
  return SignInWithGoogle(ref.read(authRepositoryProvider));
});

/// Provider para el caso de uso de OAuth con Apple
final signInWithAppleProvider = Provider<SignInWithApple>((ref) {
  return SignInWithApple(ref.read(authRepositoryProvider));
});


/// Notifier para manejar la autenticación y sus estados
class AuthNotifier extends AsyncNotifier<UserEntity?> {
  static const _tag = 'AuthNotifier';

  @override
  Future<UserEntity?> build() async {
    final repository = ref.read(authRepositoryProvider);

    // ── OAuth deep-link callback handler ──────────────────────────────────────
    //
    // Con Better Auth / Option C el flujo OAuth es:
    //   1. App llama GET /auth/oauth/{provider} → obtiene redirect URL.
    //   2. App abre URL en sistema browser.
    //   3. Backend autentica y redirige a io.sacdia.app://auth/callback
    //      con `session_token` y `provider` como query params.
    //   4. El router intercepta el deep link y llama a
    //      AuthNotifier.processOAuthDeepLink(sessionToken, provider).
    //
    // No hay listener de Supabase aquí — el deep link lo maneja el router.

    AppLogger.i('Verificando token local', tag: _tag);
    final hasToken = await repository.hasLocalToken();

    if (!hasToken) {
      AppLogger.i('Sin token local, redirigiendo a login', tag: _tag);
      return null;
    }

    // Pre-read PII and active grant from SecureStorage before the fold (reads are async).
    final secureStorage = ref.read(secureStorageProvider);
    final cachedId = await secureStorage.read(AppConstants.cachedUserId);
    final cachedEmail = await secureStorage.read(AppConstants.cachedUserEmail);
    final cachedName = await secureStorage.read(AppConstants.cachedUserName);
    final cachedAvatar = await secureStorage.read(AppConstants.cachedUserAvatar);
    final cachedAssignmentId =
        await secureStorage.read(AppConstants.cachedActiveAssignmentId);
    final cachedRoleName =
        await secureStorage.read(AppConstants.cachedActiveRoleName);
    final cachedClubType =
        await secureStorage.read(AppConstants.cachedActiveClubType);
    // cachedActiveClubName is reserved for future use — not read yet.
    final prefs = ref.read(sharedPreferencesProvider);

    AppLogger.i('Token encontrado, validando con /auth/me', tag: _tag);
    final result = await ref.read(getCurrentUserProvider)(NoParams());

    return result.fold(
      (failure) {
        if (failure is NetworkFailure) {
          AppLogger.w('Sin conectividad, intentando caché', tag: _tag);
          if (cachedId != null && cachedEmail != null) {
            AppLogger.i('Sesión restaurada desde caché', tag: _tag);
            // Session restored from cache — initialize FCM so token is
            // registered even when the backend was temporarily unreachable.
            ref.read(pushNotificationServiceProvider).initialize();

            // Reconstruct active grant from cached flat strings so widgets
            // render with the correct role immediately (no "Usuario" flash).
            AuthorizationSnapshot? cachedAuthorization;
            if (cachedAssignmentId != null) {
              final cachedGrant = AuthorizationGrant(
                assignmentId: cachedAssignmentId,
                roleName: cachedRoleName,
                clubTypeName: cachedClubType,
                status: 'active',
              );
              cachedAuthorization = AuthorizationSnapshot(
                clubAssignments: [cachedGrant],
                activeAssignmentId: cachedAssignmentId,
              );
            }

            return UserEntity(
              id: cachedId,
              email: cachedEmail,
              name: cachedName,
              avatar: cachedAvatar,
              authorization: cachedAuthorization,
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
          AppLogger.i('Usuario autenticado', tag: _tag);
          _cacheUser(user);
          // User already authenticated on startup — register FCM token.
          ref.read(pushNotificationServiceProvider).initialize();
          return user;
        }
        // Server responded but returned no user — session is invalid.
        // Do NOT restore from cache: the server explicitly rejected the token.
        AppLogger.w('Servidor respondió sin usuario, redirigiendo a login',
            tag: _tag);
        return null;
      },
    );
  }

  /// Persiste los datos del usuario para restauración offline.
  ///
  /// PII (id, email, name) se almacena en SecureStorage (cifrado en reposo).
  /// El flag post_register_complete se escribe en SharedPreferences (no PII)
  /// y también en SecureStorage para que el datasource lo lea como fallback
  /// en /auth/me.
  void _cacheUser(UserEntity user) {
    final secureStorage = ref.read(secureStorageProvider);
    // Fire-and-forget: cache writes are best-effort for offline restoration.
    secureStorage.write(AppConstants.cachedUserId, user.id);
    secureStorage.write(AppConstants.cachedUserEmail, user.email);
    if (user.name != null) {
      secureStorage.write(AppConstants.cachedUserName, user.name!);
    }
    if (user.avatar != null) {
      secureStorage.write(AppConstants.cachedUserAvatar, user.avatar!);
    } else {
      secureStorage.delete(AppConstants.cachedUserAvatar);
    }
    secureStorage.write(
      'cached_post_register_complete',
      user.postRegisterComplete.toString(),
    );
    // Keep non-PII flag in SharedPreferences for synchronous router reads.
    ref.read(sharedPreferencesProvider)
        .setBool('cached_post_register_complete', user.postRegisterComplete);

    // Cache active grant fields so the UI can render the correct role on the
    // next cold start before the /auth/me response arrives.
    final activeGrant = user.authorization?.activeGrant;
    if (activeGrant?.assignmentId != null) {
      secureStorage.write(
          AppConstants.cachedActiveAssignmentId, activeGrant!.assignmentId!);
      if (activeGrant.roleName != null) {
        secureStorage.write(AppConstants.cachedActiveRoleName, activeGrant.roleName!);
      } else {
        secureStorage.delete(AppConstants.cachedActiveRoleName);
      }
      if (activeGrant.clubTypeName != null) {
        secureStorage.write(AppConstants.cachedActiveClubType, activeGrant.clubTypeName!);
      } else {
        secureStorage.delete(AppConstants.cachedActiveClubType);
      }
      // cachedActiveClubName reserved for future use (club display name not yet in grant)
      secureStorage.delete(AppConstants.cachedActiveClubName);
    } else {
      // No active grant — clear any stale cached grant data.
      secureStorage.delete(AppConstants.cachedActiveAssignmentId);
      secureStorage.delete(AppConstants.cachedActiveRoleName);
      secureStorage.delete(AppConstants.cachedActiveClubName);
      secureStorage.delete(AppConstants.cachedActiveClubType);
    }
  }

  /// Iniciar sesión con email y contraseña
  Future<bool> signIn({required String email, required String password}) async {
    AppLogger.i('Login iniciado', tag: _tag);
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
        AppLogger.i('Login exitoso', tag: _tag);
        ref.read(sharedPreferencesProvider).setBool('user_manually_logged_out', false);
        _cacheUser(user);
        // Register FCM token after successful login (fire-and-forget).
        ref.read(pushNotificationServiceProvider).initialize();
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

  /// Procesa el callback OAuth recibido por deep link.
  ///
  /// Llamar desde el router cuando se intercepta
  /// `io.sacdia.app://auth/callback?session_token=...&provider=...`.
  ///
  /// Internamente llama a [AuthRepository.handleOAuthCallback] que envía
  /// `POST /auth/oauth/callback` al backend y recibe el JWT HS256 de SACDIA.
  Future<void> processOAuthDeepLink({
    required String sessionToken,
    required String provider,
  }) async {
    AppLogger.i('OAuth deep link recibido — provider: $provider', tag: _tag);

    if (state.valueOrNull != null) {
      AppLogger.i('Ya hay sesión activa, ignorando deep link', tag: _tag);
      return;
    }

    final repository = ref.read(authRepositoryProvider);
    final result = await repository.handleOAuthCallback(
      sessionToken: sessionToken,
      provider: provider,
    );

    result.fold(
      (failure) {
        AppLogger.e(
          'Error al procesar OAuth callback: ${failure.message}',
          tag: _tag,
        );
        state = AsyncValue.error(failure.message, StackTrace.current);
      },
      (user) {
        AppLogger.i('OAuth completado', tag: _tag);
        _cacheUser(user);
        state = AsyncValue.data(user);
        // Register FCM token after OAuth login (fire-and-forget).
        ref.read(pushNotificationServiceProvider).initialize();
      },
    );
  }

  /// Inicia el flujo OAuth con Google.
  ///
  /// Abre el navegador del sistema. El resultado llega de forma asíncrona
  /// a través del deep link. Retorna true si el navegador fue lanzado,
  /// false si hubo un error real (no el flujo normal de redirect).
  Future<OAuthLaunchResult> signInWithGoogle() async {
    AppLogger.i('OAuth Google iniciado', tag: _tag);
    state = const AsyncValue.loading();

    final result = await ref.read(signInWithGoogleProvider)(NoParams());

    return result.fold(
      (failure) {
        if (failure is OAuthFlowInitiatedFailure) {
          // El navegador fue lanzado. Resetear loading sin error.
          state = const AsyncValue.data(null);
          return OAuthLaunchResult.launched;
        }
        final errorMessage =
            failure is AuthFailure ? failure.message : 'Error al iniciar con Google';
        AppLogger.w('OAuth Google error: $errorMessage', tag: _tag);
        state = AsyncValue.error(errorMessage, StackTrace.current);
        return OAuthLaunchResult.failed;
      },
      (user) {
        _cacheUser(user);
        state = AsyncValue.data(user);
        return OAuthLaunchResult.launched;
      },
    );
  }

  /// Inicia el flujo OAuth con Apple.
  ///
  /// Misma semántica que [signInWithGoogle].
  Future<OAuthLaunchResult> signInWithApple() async {
    AppLogger.i('OAuth Apple iniciado', tag: _tag);
    state = const AsyncValue.loading();

    final result = await ref.read(signInWithAppleProvider)(NoParams());

    return result.fold(
      (failure) {
        if (failure is OAuthFlowInitiatedFailure) {
          state = const AsyncValue.data(null);
          return OAuthLaunchResult.launched;
        }
        final errorMessage =
            failure is AuthFailure ? failure.message : 'Error al iniciar con Apple';
        AppLogger.w('OAuth Apple error: $errorMessage', tag: _tag);
        state = AsyncValue.error(errorMessage, StackTrace.current);
        return OAuthLaunchResult.failed;
      },
      (user) {
        _cacheUser(user);
        state = AsyncValue.data(user);
        return OAuthLaunchResult.launched;
      },
    );
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

  /// Actualiza la contraseña del usuario autenticado.
  ///
  /// Requiere la contraseña actual para re-autenticación en el backend.
  /// Retorna null en caso de éxito, o un mensaje de error localizado.
  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    AppLogger.i('Cambio de contraseña iniciado', tag: _tag);

    final result = await ref.read(updatePasswordProvider)(
      UpdatePasswordParams(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );

    return result.fold(
      (failure) {
        final msg = failure is AuthFailure
            ? failure.message
            : 'Error al cambiar la contraseña';
        AppLogger.w('Cambio de contraseña fallido: $msg', tag: _tag);
        return msg;
      },
      (user) {
        AppLogger.i('Contraseña actualizada correctamente', tag: _tag);
        _cacheUser(user);
        state = AsyncValue.data(user);
        return null;
      },
    );
  }

  /// Called by AuthInterceptor when the refresh token is dead.
  ///
  /// Clears all local tokens and cached PII then sets state to null so
  /// GoRouter redirects to login. Does NOT make any API calls (logout
  /// endpoint, FCM unregister) because the tokens are already invalid.
  void expireSession() {
    AppLogger.w('Sesión expirada por interceptor, limpiando estado local', tag: _tag);

    final secureStorage = ref.read(secureStorageProvider);
    secureStorage.delete(AppConstants.cachedUserId);
    secureStorage.delete(AppConstants.cachedUserEmail);
    secureStorage.delete(AppConstants.cachedUserName);
    secureStorage.delete(AppConstants.cachedUserAvatar);
    secureStorage.delete('cached_post_register_complete');
    secureStorage.delete(AppConstants.cachedActiveAssignmentId);
    secureStorage.delete(AppConstants.cachedActiveRoleName);
    secureStorage.delete(AppConstants.cachedActiveClubName);
    secureStorage.delete(AppConstants.cachedActiveClubType);

    final prefs = ref.read(sharedPreferencesProvider);
    prefs.remove('cached_post_register_complete');

    state = const AsyncValue.data(null);
  }

  /// Cerrar sesión
  Future<bool> signOut() async {
    state = const AsyncValue.loading();

    // Unregister FCM token before clearing auth tokens so the Dio interceptor
    // can still attach the Bearer header for the DELETE request.
    await ref.read(pushNotificationServiceProvider).unregisterToken();

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
        prefs.remove('cached_post_register_complete');

        // PII and active grant are stored in SecureStorage — clear all on sign-out.
        final secureStorage = ref.read(secureStorageProvider);
        secureStorage.delete(AppConstants.cachedUserId);
        secureStorage.delete(AppConstants.cachedUserEmail);
        secureStorage.delete(AppConstants.cachedUserName);
        secureStorage.delete(AppConstants.cachedUserAvatar);
        secureStorage.delete('cached_post_register_complete');
        secureStorage.delete(AppConstants.cachedActiveAssignmentId);
        secureStorage.delete(AppConstants.cachedActiveRoleName);
        secureStorage.delete(AppConstants.cachedActiveClubName);
        secureStorage.delete(AppConstants.cachedActiveClubType);

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

/// Resultado de intentar lanzar un flujo OAuth.
enum OAuthLaunchResult {
  /// El navegador fue abierto y el flujo está en curso.
  launched,

  /// Ocurrió un error antes de poder abrir el navegador.
  failed,
}
