import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/social_auth_provider.dart';
import '../../../../core/auth/social_credential.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../providers/storage_provider.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/authorization_snapshot.dart';
import '../../domain/entities/delete_account_reauth.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/reset_password_request.dart';
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
import '../../../biometric/presentation/providers/biometric_provider.dart';
import '../../../notifications/presentation/providers/unread_notifications_count_provider.dart';

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
      socialAuth: ref.read(socialAuthClientProvider),
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

/// Clears biometric app-lock opt-in when the authenticated session ends.
///
/// Current release scope: biometrics protect an existing local session; they do
/// not replace login. Therefore the opt-in is session-scoped and must not
/// survive logout, account deletion, or session expiration.
Future<void> clearSessionScopedBiometricOptIn(
  SharedPreferences prefs,
) async {
  await prefs.remove(AppConstants.biometricEnabledKey);
  await prefs.remove(AppConstants.biometricEnrolledAtKey);
}

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

/// Provider para el caso de uso de recuperación de contraseña
final resetPasswordRequestProvider = Provider<ResetPasswordRequest>((ref) {
  return ResetPasswordRequest(ref.read(authRepositoryProvider));
});

/// Provider para el caso de uso de login nativo con Google
final signInWithGoogleProvider = Provider<SignInWithGoogle>((ref) {
  return SignInWithGoogle(ref.read(authRepositoryProvider));
});

/// Provider para el caso de uso de login nativo con Apple
final signInWithAppleProvider = Provider<SignInWithApple>((ref) {
  return SignInWithApple(ref.read(authRepositoryProvider));
});

/// Notifier para solicitar recuperación de contraseña sin acoplar la vista al repositorio.
class ForgotPasswordNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submit(String email) async {
    state = const AsyncValue.loading();

    final result = await ref.read(resetPasswordRequestProvider)(
      ResetPasswordRequestParams(email: email),
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }
}

/// Provider para recuperación de contraseña.
final forgotPasswordNotifierProvider =
    AsyncNotifierProvider.autoDispose<ForgotPasswordNotifier, void>(
  ForgotPasswordNotifier.new,
);

/// Notifier para manejar la autenticación y sus estados
class AuthNotifier extends AsyncNotifier<UserEntity?> {
  static const _tag = 'AuthNotifier';

  List<String> _decodeCachedPermissions(String? rawPermissions) {
    if (rawPermissions == null || rawPermissions.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawPermissions);
      if (decoded is List) {
        return decoded
            .map((value) => value?.toString().trim().toLowerCase())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();
      }
    } catch (_) {
      // Legacy/debug fallback: tolerate comma-separated values.
    }

    return rawPermissions
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  int? _parseCachedInt(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }

  @override
  Future<UserEntity?> build() async {
    final repository = ref.read(authRepositoryProvider);

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
    final cachedAvatar =
        await secureStorage.read(AppConstants.cachedUserAvatar);
    final cachedAssignmentId =
        await secureStorage.read(AppConstants.cachedActiveAssignmentId);
    final cachedRoleName =
        await secureStorage.read(AppConstants.cachedActiveRoleName);
    final cachedClubType =
        await secureStorage.read(AppConstants.cachedActiveClubType);
    final cachedActivePermissions = _decodeCachedPermissions(
      await secureStorage.read(AppConstants.cachedActivePermissions),
    );
    final cachedClubId = _parseCachedInt(
      await secureStorage.read(AppConstants.cachedActiveClubId),
    );
    final cachedSectionId = _parseCachedInt(
      await secureStorage.read(AppConstants.cachedActiveSectionId),
    );
    final cachedClubTypeId = _parseCachedInt(
      await secureStorage.read(AppConstants.cachedActiveClubTypeId),
    );
    final cachedClubName =
        await secureStorage.read(AppConstants.cachedActiveClubName);
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
            ref.read(unreadNotificationsCountProvider.notifier).refresh();

            // Reconstruct active grant from cached flat strings so widgets
            // render with the correct role immediately (no "Usuario" flash).
            AuthorizationSnapshot? cachedAuthorization;
            if (cachedAssignmentId != null) {
              final cachedGrant = AuthorizationGrant(
                assignmentId: cachedAssignmentId,
                roleName: cachedRoleName,
                permissions: cachedActivePermissions,
                clubId: cachedClubId,
                clubName: cachedClubName,
                sectionId: cachedSectionId,
                clubTypeId: cachedClubTypeId,
                clubTypeName: cachedClubType,
                status: 'active',
              );
              cachedAuthorization = AuthorizationSnapshot(
                effectivePermissions: cachedActivePermissions,
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
          ref.read(unreadNotificationsCountProvider.notifier).refresh();
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
    ref
        .read(sharedPreferencesProvider)
        .setBool('cached_post_register_complete', user.postRegisterComplete);

    // Cache active grant fields so the UI can render the correct role on the
    // next cold start before the /auth/me response arrives.
    final activeGrant = user.authorization?.activeGrant;
    if (activeGrant?.assignmentId != null) {
      secureStorage.write(
          AppConstants.cachedActiveAssignmentId, activeGrant!.assignmentId!);
      if (activeGrant.roleName != null) {
        secureStorage.write(
            AppConstants.cachedActiveRoleName, activeGrant.roleName!);
      } else {
        secureStorage.delete(AppConstants.cachedActiveRoleName);
      }
      if (activeGrant.clubTypeName != null) {
        secureStorage.write(
            AppConstants.cachedActiveClubType, activeGrant.clubTypeName!);
      } else {
        secureStorage.delete(AppConstants.cachedActiveClubType);
      }
      final permissionsToCache =
          (user.authorization?.effectivePermissions.isNotEmpty ?? false)
              ? user.authorization!.effectivePermissions
              : activeGrant.permissions;
      if (permissionsToCache.isNotEmpty) {
        secureStorage.write(
          AppConstants.cachedActivePermissions,
          jsonEncode(permissionsToCache),
        );
      } else {
        secureStorage.delete(AppConstants.cachedActivePermissions);
      }
      if (activeGrant.clubId != null) {
        secureStorage.write(
          AppConstants.cachedActiveClubId,
          activeGrant.clubId!.toString(),
        );
      } else {
        secureStorage.delete(AppConstants.cachedActiveClubId);
      }
      if (activeGrant.sectionId != null) {
        secureStorage.write(
          AppConstants.cachedActiveSectionId,
          activeGrant.sectionId!.toString(),
        );
      } else {
        secureStorage.delete(AppConstants.cachedActiveSectionId);
      }
      if (activeGrant.clubTypeId != null) {
        secureStorage.write(
          AppConstants.cachedActiveClubTypeId,
          activeGrant.clubTypeId!.toString(),
        );
      } else {
        secureStorage.delete(AppConstants.cachedActiveClubTypeId);
      }
      final clubNameToCache = activeGrant.clubName?.trim();
      if (clubNameToCache != null && clubNameToCache.isNotEmpty) {
        secureStorage.write(
          AppConstants.cachedActiveClubName,
          clubNameToCache,
        );
      } else {
        secureStorage.delete(AppConstants.cachedActiveClubName);
      }
    } else {
      // No active grant — clear any stale cached grant data.
      secureStorage.delete(AppConstants.cachedActiveAssignmentId);
      secureStorage.delete(AppConstants.cachedActiveRoleName);
      secureStorage.delete(AppConstants.cachedActiveClubName);
      secureStorage.delete(AppConstants.cachedActiveClubType);
      secureStorage.delete(AppConstants.cachedActivePermissions);
      secureStorage.delete(AppConstants.cachedActiveClubId);
      secureStorage.delete(AppConstants.cachedActiveSectionId);
      secureStorage.delete(AppConstants.cachedActiveClubTypeId);
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
            : 'auth.errors.sign_in_failed'.tr();
        AppLogger.w('Login fallido: $errorMessage', tag: _tag);
        return AsyncValue.error(errorMessage, StackTrace.current);
      },
      (user) {
        AppLogger.i('Login exitoso', tag: _tag);
        ref
            .read(sharedPreferencesProvider)
            .setBool('user_manually_logged_out', false);
        _cacheUser(user);
        // Register FCM token after successful login (fire-and-forget).
        ref.read(pushNotificationServiceProvider).initialize();
        ref.read(unreadNotificationsCountProvider.notifier).refresh();
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
            : 'auth.errors.sign_up_failed'.tr();
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
      birthday: current.birthday,
      metadata: current.metadata,
      authorization: current.authorization,
      lastSignInAt: current.lastSignInAt,
      createdAt: current.createdAt,
      postRegisterComplete: true,
    );
    state = AsyncValue.data(updatedUser);
    _cacheUser(updatedUser);
  }

  void markPostRegisterIncomplete() {
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
      postRegisterComplete: false,
    );
    state = AsyncValue.data(updatedUser);
    _cacheUser(updatedUser);
  }

  Future<UserEntity?> refreshCurrentUser({
    bool keepCurrentOnFailure = false,
  }) async {
    final result = await ref.read(getCurrentUserProvider)(NoParams());

    return result.fold(
      (failure) {
        final errorMessage = failure is AuthFailure
            ? failure.message
            : 'common.error_generic'.tr();
        AppLogger.w('Error al refrescar usuario: $errorMessage', tag: _tag);
        if (!keepCurrentOnFailure) {
          state = AsyncValue.error(errorMessage, StackTrace.current);
        }
        return null;
      },
      (user) {
        if (user != null) {
          _cacheUser(user);
        }
        state = AsyncValue.data(user);
        return user;
      },
    );
  }

  /// Login con Google (SDK nativo).
  Future<SocialSignInResult> signInWithGoogle() =>
      _signInSocial('google', ref.read(signInWithGoogleProvider));

  /// Login con Apple (SDK nativo, solo iOS).
  Future<SocialSignInResult> signInWithApple() =>
      _signInSocial('apple', ref.read(signInWithAppleProvider));

  Future<SocialSignInResult> _signInSocial(
    String provider,
    UseCase<UserEntity, NoParams> useCase,
  ) async {
    AppLogger.i('Login social iniciado: $provider', tag: _tag);
    // No se pasa por AsyncLoading: el router manda a /splash mientras el auth
    // carga, lo que desmontaría LoginView detrás de la hoja nativa. El botón
    // muestra su propio estado de carga.
    // Un error previo (banner del login) se limpia al empezar un nuevo intento;
    // pasar a data(null) no dispara el redirect a /splash.
    if (state is AsyncError) {
      state = const AsyncValue.data(null);
    }

    final result = await useCase(const NoParams());

    return result.fold(
      (failure) {
        if (failure is SocialSignInCancelledFailure) {
          AppLogger.i('Login social cancelado: $provider', tag: _tag);
          return SocialSignInResult.cancelled;
        }
        final errorMessage = failure is AuthFailure
            ? failure.message
            : 'errors.social_signin_failed'.tr(
                namedArgs: {
                  'provider': provider == 'apple' ? 'Apple' : 'Google'
                },
              );
        AppLogger.w('Login social $provider falló: $errorMessage', tag: _tag);
        state = AsyncValue.error(errorMessage, StackTrace.current);
        return SocialSignInResult.failed;
      },
      (user) {
        AppLogger.i('Login social exitoso: $provider', tag: _tag);
        ref
            .read(sharedPreferencesProvider)
            .setBool('user_manually_logged_out', false);
        _cacheUser(user);
        // Mismos efectos que signIn(): FCM y badge de notificaciones.
        ref.read(pushNotificationServiceProvider).initialize();
        ref.read(unreadNotificationsCountProvider.notifier).refresh();
        state = AsyncValue.data(user);
        return SocialSignInResult.success;
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

    // Capture old activeAssignmentId for diagnostics.
    final oldActiveId = state.valueOrNull?.authorization?.activeAssignmentId;

    final refreshResult = await ref.read(getCurrentUserProvider)(NoParams());
    refreshResult.fold(
      (failure) => AppLogger.w(
        'Error al refrescar usuario tras cambio de contexto: ${failure.message}',
        tag: _tag,
      ),
      (user) {
        if (user != null) {
          final newActiveId = user.authorization?.activeAssignmentId;
          AppLogger.i(
            'switchContext refresh: requested=$assignmentId, '
            'old=$oldActiveId, new=$newActiveId, '
            'match=${newActiveId == assignmentId}',
            tag: _tag,
          );
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
            : 'auth.errors.change_password_failed'.tr();
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

  /// Elimina permanentemente la cuenta del usuario autenticado.
  ///
  /// Flujo:
  ///  1. Llama DELETE /auth/me con la reautenticación (contraseña o proveedor).
  ///  2. En éxito limpia FCM y todo el storage local y pone state = null.
  ///     En fallo no toca nada: el usuario sigue con sesión y push activo.
  ///
  /// Retorna null en éxito o un mensaje de error localizado.
  Future<String?> deleteAccount(DeleteAccountReauth reauth) async {
    AppLogger.i('Iniciando eliminación de cuenta', tag: _tag);

    // Confirmación biométrica antes de cualquier efecto destructivo
    // (no-op si el usuario no tiene biometría habilitada).
    final bioOk = await requireBiometricConfirmationRef(
      ref,
      reason: 'biometric.confirm_delete_account'.tr(),
    );
    if (!bioOk) {
      AppLogger.w('Delete account cancelado por biometría', tag: _tag);
      return 'auth.errors.operation_cancelled'.tr();
    }

    final result = await ref.read(authRepositoryProvider).deleteAccount(reauth);

    return result.fold<Future<String?>>(
      (failure) async {
        final msg = failure is AuthFailure
            ? failure.message
            : 'auth.errors.delete_account_failed'.tr();
        AppLogger.w('Delete account fallido: $msg', tag: _tag);
        return msg;
      },
      (_) async {
        AppLogger.i('Cuenta eliminada correctamente', tag: _tag);

        // Solo en éxito: si el borrado falla el usuario sigue con sesión y
        // debe conservar las notificaciones push. El backend ya desactivó sus
        // tokens FCM en la cascada; esto limpia el registro local y cancela
        // los listeners (best-effort, el DELETE puede fallar sin sesión).
        try {
          final pushService = ref.read(pushNotificationServiceProvider);
          await pushService.unregisterToken();
          await pushService.dispose();
        } catch (e) {
          AppLogger.w('Error al limpiar FCM tras delete account',
              tag: _tag, error: e);
        }

        // Limpiar estado local (el datasource ya limpió tokens en deleteAccount).
        final prefs = ref.read(sharedPreferencesProvider);
        prefs.remove('cached_post_register_complete');
        prefs.remove('user_manually_logged_out');
        await clearSessionScopedBiometricOptIn(prefs);
        ref.invalidate(biometricProvider);
        // Limpiar claves de notif prefs para que no queden datos huérfanos.
        for (final key in const [
          'notif_push_master',
          'notif_push_activities',
          'notif_push_achievements',
          'notif_push_approvals',
          'notif_push_invitations',
          'notif_push_reminders',
        ]) {
          prefs.remove(key);
        }

        ref.read(unreadNotificationsCountProvider.notifier).setZero();
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  /// Proveedores sociales vinculados, para ofrecer la confirmación sin
  /// contraseña al borrar la cuenta. Lista vacía si la consulta falla.
  Future<List<SocialProvider>> connectedProviders() async {
    final result =
        await ref.read(authRepositoryProvider).getConnectedProviders();
    return result.fold((_) => const [], (list) => list);
  }

  /// Called by AuthInterceptor when the refresh token is dead.
  ///
  /// Clears all local tokens and cached PII then sets state to null so
  /// GoRouter redirects to login. Does NOT make any API calls (logout
  /// endpoint, FCM unregister) because the tokens are already invalid.
  void expireSession() {
    AppLogger.w('Sesión expirada por interceptor, limpiando estado local',
        tag: _tag);

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
    secureStorage.delete(AppConstants.cachedActivePermissions);
    secureStorage.delete(AppConstants.cachedActiveClubId);
    secureStorage.delete(AppConstants.cachedActiveSectionId);
    secureStorage.delete(AppConstants.cachedActiveClubTypeId);

    final prefs = ref.read(sharedPreferencesProvider);
    prefs.remove('cached_post_register_complete');
    unawaited(clearSessionScopedBiometricOptIn(prefs));
    ref.invalidate(biometricProvider);

    state = const AsyncValue.data(null);
  }

  /// Cerrar sesión
  Future<bool> signOut() async {
    state = const AsyncValue.loading();

    // Unregister FCM token before clearing auth tokens so the Dio interceptor
    // can still attach the Bearer header for the DELETE request.
    // dispose() cancels all stream listeners to prevent duplicate handlers
    // if the user logs in again in the same session.
    final pushService = ref.read(pushNotificationServiceProvider);
    await pushService.unregisterToken();
    await pushService.dispose();
    // Clear unread counter immediately so any badge shows 0 after logout.
    ref.read(unreadNotificationsCountProvider.notifier).setZero();

    final result = await ref.read(signOutProvider)(NoParams());

    return result.fold<Future<bool>>(
      (failure) async {
        final errorMessage = failure is AuthFailure
            ? failure.message
            : 'auth.errors.sign_out_failed'.tr();
        state = AsyncValue.error(errorMessage, StackTrace.current);
        return false;
      },
      (_) async {
        state = const AsyncValue.data(null);

        final prefs = ref.read(sharedPreferencesProvider);
        prefs.setBool('user_manually_logged_out', true);
        prefs.remove('cached_post_register_complete');
        await clearSessionScopedBiometricOptIn(prefs);
        ref.invalidate(biometricProvider);

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
        secureStorage.delete(AppConstants.cachedActivePermissions);
        secureStorage.delete(AppConstants.cachedActiveClubId);
        secureStorage.delete(AppConstants.cachedActiveSectionId);
        secureStorage.delete(AppConstants.cachedActiveClubTypeId);

        return true;
      },
    );
  }
}

/// `true` mientras hay un login social en curso (hoja nativa abierta o POST al
/// backend). El estado global de auth no pasa por loading en ese tiempo, así
/// que el login por correo lo consulta para no competir con él.
final socialSignInInFlightProvider = StateProvider<bool>((ref) => false);

/// Provider para NetworkInfo
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl();
});

/// Provider para AuthNotifier
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, UserEntity?>(() {
  return AuthNotifier();
});

/// Resultado de un intento de login social desde la UI.
enum SocialSignInResult {
  /// Sesión iniciada; el router redirige según `postRegisterComplete`.
  success,

  /// El usuario cerró la hoja nativa. No se muestra nada.
  cancelled,

  /// Error real; el mensaje queda en `authNotifierProvider.error`.
  failed,
}
