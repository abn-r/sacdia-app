import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/acting_for_session.dart';
import '../../../../core/auth/session_mode.dart';
import '../../../../core/auth/social_auth_provider.dart';
import '../../../../core/auth/social_credential.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/network/interceptors/acting_error_interceptor.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../providers/storage_provider.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/authorization_snapshot.dart';
import '../../domain/entities/delete_account_reauth.dart';
import '../../domain/entities/principal_info.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/utils/registration_age_gate.dart';
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
import '../../../device_mode/domain/entities/device_pairing.dart';
import '../../../device_mode/presentation/providers/device_notice_provider.dart';
import '../../../device_mode/presentation/providers/device_pairing_providers.dart';
import '../../../notifications/presentation/providers/unread_notifications_count_provider.dart';
import '../login_error_messages.dart';
import 'acting_providers.dart';
import 'login_notice_provider.dart';
import 'profile_scope_purge.dart';

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
      actingForSession: ref.read(actingForSessionProvider),
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

/// Resultado de [AuthNotifier.switchProfile].
enum SwitchProfileOutcome {
  /// Ahora se actúa por el dependiente pedido.
  entered,

  /// Se volvió al perfil del tutor.
  exited,

  /// Ya se estaba en ese perfil: no se hizo nada.
  unchanged,

  /// Otro cambio de perfil posterior tomó el control; este se descartó.
  superseded,

  /// El servidor negó el acceso (`ACTING_FOR_FORBIDDEN`): se volvió al tutor y
  /// se avisó con [ActingNotice.accessRevoked].
  accessRevoked,

  /// Sin conexión: se volvió al tutor (sin restaurar al dependiente de caché).
  offline,

  /// Cualquier otro fallo: se volvió al tutor.
  failed,
}

/// Notifier para manejar la autenticación y sus estados
/// ¿Ya se puede pedir el permiso de notificaciones para [user]?
///
/// Solo cuando terminó el post-registro y aceptó los documentos legales: antes
/// el aviso del sistema tapaba el registro. Un teléfono vinculado no tiene
/// post-registro de cuenta, así que siempre está listo.
@visibleForTesting
bool pushReadyFor(UserEntity user) {
  if (user.isLinkedDevice) return true;
  return user.postRegisterComplete && !user.legalAcceptancePending;
}

class AuthNotifier extends AsyncNotifier<UserEntity?> {
  static const _tag = 'AuthNotifier';

  /// Se incrementa en cada cambio de perfil y en cada salida del modo "actuar
  /// por". Un cambio en vuelo compara su valor al volver de la red: si ya no
  /// coincide, otro cambio posterior tomó el control y el resultado se tira.
  int _switchEpoch = 0;

  ActingForSession get _session => ref.read(actingForSessionProvider);

  SessionModeStore get _sessionModeStore =>
      SessionModeStore(ref.read(secureStorageProvider));

  bool get _isActing => _session.isActing;

  /// Registra el token FCM del usuario actual. Nunca mientras se actúa por un
  /// dependiente: el dispositivo y sus notificaciones son del tutor (FP-49).
  ///
  /// Pedir el permiso de notificaciones (lo hace `initialize`) espera a que la
  /// cuenta termine el post-registro y acepte los documentos legales: así el
  /// aviso del sistema no aparece encima del registro. [markPostRegisterComplete]
  /// y [markLegalAccepted] vuelven a llamar aquí. Un teléfono vinculado no
  /// pasa por el post-registro de cuenta y se registra de inmediato.
  void _registerPush([UserEntity? user]) {
    if (_isActing) return;
    final current = user ?? state.valueOrNull;
    if (current != null && !pushReadyFor(current)) return;
    ref.read(pushNotificationServiceProvider).initialize();
  }

  Future<void> _setActingDirty(bool value) =>
      ref.read(sharedPreferencesProvider).setBool(kActingDirtyPrefsKey, value);

  /// `true` si el fallo significa que ya no se puede actuar por ese dependiente.
  static bool _isAccessRevoked(Failure failure) =>
      failure is AuthFailure &&
      (failure.errorCode == ActingErrorInterceptor.forbiddenCode ||
          failure.code == 403);

  /// Arranque en frío tras morir la app actuando (FP-51): purga los cachés de
  /// disco y baja la bandera. Dentro de un proceso vivo la bandera solo está
  /// arriba mientras se actúa, por eso se exige que NO se esté actuando.
  Future<void> _cleanupAfterDirtyShutdown() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(kActingDirtyPrefsKey) != true || _isActing) return;
    AppLogger.w('Arranque tras morir actuando: purgando cachés', tag: _tag);
    // `cachedUserId` solo se escribe como tutor (`_cacheUser` no corre
    // actuando): es el único usuario cuyas marcas de salud se conservan.
    final guardianId =
        await ref.read(secureStorageProvider).read(AppConstants.cachedUserId);
    await purgeProfileScopeDiskCaches(
      ref,
      guardianUserId: guardianId,
      clearImages: true,
    );
    await _setActingDirty(false);
  }

  /// Sale del modo "actuar por" SIN recargar al usuario: baja la sesión, purga
  /// el estado del perfil, baja la bandera y descarta la foto del tutor.
  ///
  /// Devuelve el epoch asignado para que el llamador sepa si otro cambio de
  /// perfil lo reemplazó mientras esperaba.
  Future<int> _abandonActing({ActingNotice? notice}) async {
    final epoch = ++_switchEpoch;
    final wasActing = _session.isActing;
    // El id del tutor se toma ANTES de soltar su foto: la purga de disco
    // conserva solo sus marcas de salud.
    final guardianId = ref.read(guardianUserProvider)?.id;
    _session.exit();
    ref.read(guardianUserProvider.notifier).state = null;
    if (notice != null) {
      ref.read(actingNoticeProvider.notifier).state = notice;
    }
    if (!wasActing) return epoch;
    purgeProfileScopeProviders(ref);
    await purgeProfileScopeDiskCaches(
      ref,
      guardianUserId: guardianId,
      clearImages: true,
    );
    await _setActingDirty(false);
    return epoch;
  }

  /// Vuelve al tutor y lo recarga (`/auth/me` sin encabezado; sin red, el
  /// tutor cacheado). Nada del dependiente se restaura jamás.
  Future<void> _exitActing({ActingNotice? notice}) async {
    if (!_session.isActing) return;
    state = const AsyncLoading();
    final epoch = await _abandonActing(notice: notice);
    if (epoch != _switchEpoch) return;
    ref.invalidateSelf();
  }

  /// Cierra el modo "actuar por" antes de un logout o una expiración de sesión.
  /// Los cachés de disco los purga `clearUserStateOnLogout` al quedar sin usuario.
  void _clearActingForLogout() {
    _switchEpoch++;
    _session.exit();
    ref.read(guardianUserProvider.notifier).state = null;
    ref.read(actingNoticeProvider.notifier).state = null;
  }

  /// Llamado por el interceptor cuando una petición del perfil vigente recibe
  /// 403 `ACTING_FOR_FORBIDDEN`: sale a la vista del tutor con un aviso.
  /// `ACTING_FOR_SCOPE_DENIED` NO llega aquí (no expulsa, FP-55).
  void onActingForbidden(String dependentUserId) {
    if (_session.dependentUserId != dependentUserId) return;
    unawaited(_exitActing(notice: ActingNotice.accessRevoked));
  }

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
      // Sin sesión no hay modo: una bandera de dispositivo huérfana (sesión
      // borrada por el servidor, app reinstalada...) no sobrevive.
      ref.read(sessionModeProvider.notifier).state = SessionMode.account;
      unawaited(_sessionModeStore.clear());
      return null;
    }

    // La cáscara de un teléfono vinculado se elige ANTES de que `/auth/me`
    // responda (también sin red). `/auth/me.principal.kind` manda: si dice
    // otra cosa, se reescribe más abajo.
    final persistedMode = await _sessionModeStore.read();
    ref.read(sessionModeProvider.notifier).state = persistedMode;

    // Si la app murió actuando por un menor, sus cachés de disco se purgan
    // antes de cargar nada (sin sesión no hay nada que proteger: el logout ya
    // los purgó).
    await _cleanupAfterDirtyShutdown();

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
    final generationAtStart = _session.generation;
    final result = await ref.read(getCurrentUserProvider)(NoParams());

    // El perfil cambió mientras volaba /auth/me: la respuesta es de otro perfil.
    if (_session.generation != generationAtStart) {
      AppLogger.i('Perfil cambiado durante la carga, recargando', tag: _tag);
      return build();
    }

    // Mientras se actúa, cualquier fallo (o un usuario vacío) saca al tutor:
    // devolver `null` aquí cerraría la sesión, y restaurar de caché devolvería
    // al dependiente como si fuera quien inició sesión (FP-50).
    if (_isActing) {
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      final user = result.fold<UserEntity?>((_) => null, (u) => u);
      if (failure != null || user == null) {
        AppLogger.w('Fallo al cargar el perfil dependiente, volviendo al tutor',
            tag: _tag);
        await _abandonActing(
          notice: failure != null && _isAccessRevoked(failure)
              ? ActingNotice.accessRevoked
              : null,
        );
        return build();
      }
    }

    return result.fold(
      (failure) {
        if (failure is NetworkFailure) {
          AppLogger.w('Sin conectividad, intentando caché', tag: _tag);
          if (cachedId != null) {
            AppLogger.i('Sesión restaurada desde caché', tag: _tag);
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

            final cachedUser = UserEntity(
              id: cachedId,
              email: cachedEmail,
              name: cachedName,
              avatar: cachedAvatar,
              authorization: cachedAuthorization,
              postRegisterComplete:
                  prefs.getBool('cached_post_register_complete') ?? false,
              // Server is the truth; never cache pending. Offline restore
              // cannot know the legal status, so it stays false.
              legalAcceptancePending: false,
              // Un teléfono vinculado se restaura SIEMPRE como tal: la bandera
              // del almacenamiento seguro solo elige la cáscara (nunca otorga
              // nada; el servidor sigue siendo quien deniega).
              principal: persistedMode == SessionMode.device
                  ? const PrincipalInfo(kind: PrincipalKind.linkedDevice)
                  : null,
            );
            // Session restored from cache — initialize FCM so token is
            // registered even when the backend was temporarily unreachable.
            _registerPush(cachedUser);
            return cachedUser;
          }
          AppLogger.i('Sin caché, redirigiendo a login', tag: _tag);
          return null;
        }
        AppLogger.e('Error al validar token: ${failure.message}', tag: _tag);
        return null;
      },
      (loaded) {
        if (loaded != null) {
          AppLogger.i('Usuario autenticado', tag: _tag);
          // El servidor manda sobre la bandera local: reescribe el modo y, si
          // la bandera dice dispositivo pero el principal no llegó, falla
          // cerrado (cuenta restringida, nunca adulto).
          final user = _reconcileSessionMode(loaded, persistedMode);
          // Mientras se actúa: ni caché del usuario ni FCM (FP-49); ambos
          // son del tutor y `_cacheUser` ya lo respeta.
          _cacheUser(user);
          // User already authenticated on startup — register FCM token.
          _registerPush(user);
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
    // Mientras se actúa, `user` es el dependiente: lo que se cachea es lo que
    // `build()` restaura sin red, así que escribirlo traería al niño de vuelta
    // como si fuera quien inició sesión (FP-49).
    if (_isActing) return;
    final secureStorage = ref.read(secureStorageProvider);
    // Fire-and-forget: cache writes are best-effort for offline restoration.
    secureStorage.write(AppConstants.cachedUserId, user.id);
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      secureStorage.write(AppConstants.cachedUserEmail, email);
    } else {
      secureStorage.delete(AppConstants.cachedUserEmail);
    }
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

  /// Iniciar sesión con correo o usuario (handle) y contraseña.
  ///
  /// El [identifier] no se valida ni se registra. Un fallo deja en el estado un
  /// mensaje traducido por `code` ([loginErrorMessage]), nunca texto crudo.
  Future<bool> signIn({
    required String identifier,
    required String password,
  }) async {
    AppLogger.i('Login iniciado', tag: _tag);
    // Un intento nuevo descarta el aviso de "acceso revocado" del anterior.
    ref.read(loginNoticeProvider.notifier).state = null;
    // El router manda a /splash mientras carga y la pantalla de login se
    // desmonta: lo escrito se conserva para rellenarlo al volver.
    ref.read(lastLoginIdentifierProvider.notifier).state = identifier;
    state = const AsyncValue.loading();

    final result = await ref.read(signInProvider)(
      SignInParams(identifier: identifier, password: password),
    );

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      AppLogger.w('Login fallido (${failure.errorCode ?? failure.code})',
          tag: _tag);
      state = AsyncValue.error(loginErrorMessage(failure), StackTrace.current);
      return false;
    }

    // El POST /auth/login ya creó la sesión, pero la sesión solo sirve si
    // `/auth/me` también responde.
    final loginUser = result.getOrElse(() => throw StateError('unreachable'));
    final session = await _confirmSessionAfterLogin(loginUser);
    if (session.error != null) {
      state = AsyncValue.error(session.error!, StackTrace.current);
      return false;
    }
    final user = session.user!;

    AppLogger.i('Login exitoso', tag: _tag);
    ref.read(lastLoginIdentifierProvider.notifier).state = '';
    ref
        .read(sharedPreferencesProvider)
        .setBool('user_manually_logged_out', false);
    _cacheUser(user);
    // Register FCM token after successful login (fire-and-forget).
    _registerPush(user);
    ref.read(unreadNotificationsCountProvider.notifier).refresh();
    state = AsyncValue.data(user);
    return true;
  }

  /// Tras un login (correo o social) pide `/auth/me` y devuelve el usuario
  /// completo, que reemplaza al del login. Si falla (500, sin red, respuesta
  /// vacía) NO se deja una sesión a medias: se cierra la sesión recién creada
  /// (tokens y cachés locales) y se devuelve un mensaje traducido por código
  /// ([userErrorMessage]), nunca texto crudo.
  Future<({UserEntity? user, String? error})> _confirmSessionAfterLogin(
    UserEntity loginUser,
  ) async {
    final me = await ref.read(getCurrentUserProvider)(NoParams());
    final failure = me.fold<Failure?>((f) => f, (_) => null);
    final user = me.fold<UserEntity?>((_) => null, (u) => u);
    if (failure == null && user != null) return (user: user, error: null);

    AppLogger.w(
      'Login correcto pero /auth/me falló (${failure?.errorCode ?? failure?.code ?? 'sin usuario'}); se cierra la sesión',
      tag: _tag,
    );
    // Cierre fail-safe: limpia tokens y cachés aunque el servidor no responda.
    try {
      await ref.read(signOutProvider)(NoParams());
    } catch (_) {}
    ref.read(unreadNotificationsCountProvider.notifier).setZero();
    return (
      user: null,
      error: userErrorMessage(
        failure,
        fallbackKey: 'auth.errors.session_load_failed',
      ),
    );
  }

  /// Quita un error que ya mostró otra pantalla (el registro), para que el
  /// login no lo herede al volver.
  void clearError() {
    if (state is AsyncError) state = const AsyncValue.data(null);
  }

  /// Registrar un nuevo usuario
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
    required String acceptedTermsVersion,
    required String acceptedPrivacyVersion,
    String? birthday,
  }) async {
    // No se pasa por AsyncLoading: el registro se abre con push sobre el
    // login y el redirect ve '/login', así que mandaría a /splash y
    // desmontaría el formulario (se perdían los datos y el error). La vista
    // muestra su propio estado de carga. Un error previo se limpia aquí.
    if (state is AsyncError) {
      state = const AsyncValue.data(null);
    }

    final result = await ref.read(signUpProvider)(
      SignUpParams(
        email: email,
        password: password,
        name: name,
        paternalSurname: paternalSurname,
        maternalSurname: maternalSurname,
        acceptedTermsVersion: acceptedTermsVersion,
        acceptedPrivacyVersion: acceptedPrivacyVersion,
        birthday: birthday,
      ),
    );

    state = result.fold(
      (failure) {
        // Menor del mínimo: el formulario muestra la pantalla de bloqueo.
        if (failure.errorCode == kRegistrationAgeBelowMinimumCode) {
          return AsyncValue.error(
            const RegistrationAgeBelowMinimum(),
            StackTrace.current,
          );
        }
        final errorMessage = failure is AuthFailure
            ? failure.message
            : 'auth.errors.sign_up_failed'.tr();
        return AsyncValue.error(errorMessage, StackTrace.current);
      },
      (user) => AsyncValue.data(user),
    );

    return !state.hasError;
  }

  /// El usuario sobre el que una marca en memoria puede actuar, o `null` si no
  /// debe aplicarse (S1).
  ///
  /// Durante un cambio de perfil `AsyncLoading` conserva el valor previo en
  /// `valueOrNull`: una llamada tardía del post-registro reescribiría ese valor
  /// como dato y republicaría al perfil anterior (y lo guardaría en caché). Por
  /// eso no se aplica mientras carga ni si [forUserId] —el usuario que inició la
  /// operación— ya no es el vigente.
  UserEntity? _markTarget(String? forUserId) {
    if (state.isLoading) return null;
    final current = state.valueOrNull;
    if (current == null) return null;
    if (forUserId != null && forUserId != current.id) return null;
    return current;
  }

  /// Marks the current user's post-registration as complete in the in-memory
  /// auth state. Call this after step 3 is successfully saved so the router
  /// redirects correctly without waiting for a full /auth/me refresh.
  ///
  /// Pasa [forUserId] (el usuario que inició la operación) para que una
  /// llamada tardía no marque a otro perfil.
  void markPostRegisterComplete({String? forUserId}) {
    final current = _markTarget(forUserId);
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
      legalAcceptancePending: current.legalAcceptancePending,
      actingFor: current.actingFor,
      family: current.family,
      principal: current.principal,
      familyFeatures: current.familyFeatures,
      analyticsAnonymous: current.analyticsAnonymous,
      serverMode: current.serverMode,
    );
    state = AsyncValue.data(updatedUser);
    _cacheUser(updatedUser);
    // Terminó el post-registro: ahora sí se pide el permiso de notificaciones.
    _registerPush(updatedUser);
  }

  /// Clears the legal-acceptance gate in the in-memory auth state after the
  /// backend confirmed the current versions were accepted, so the router
  /// leaves the gate without a full /auth/me refresh.
  void markLegalAccepted() {
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
      postRegisterComplete: current.postRegisterComplete,
      legalAcceptancePending: false,
      actingFor: current.actingFor,
      family: current.family,
      principal: current.principal,
      familyFeatures: current.familyFeatures,
      analyticsAnonymous: current.analyticsAnonymous,
      serverMode: current.serverMode,
    );
    state = AsyncValue.data(
        updatedUser); // Aceptó los documentos: si ya terminó el registro, pide el permiso.
    _registerPush(updatedUser);
  }

  void markPostRegisterIncomplete({String? forUserId}) {
    final current = _markTarget(forUserId);
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
      legalAcceptancePending: current.legalAcceptancePending,
      actingFor: current.actingFor,
      family: current.family,
      principal: current.principal,
      familyFeatures: current.familyFeatures,
      analyticsAnonymous: current.analyticsAnonymous,
      serverMode: current.serverMode,
    );
    state = AsyncValue.data(updatedUser);
    _cacheUser(updatedUser);
  }

  Future<UserEntity?> refreshCurrentUser({
    bool keepCurrentOnFailure = false,
  }) async {
    final generationAtStart = _session.generation;
    final result = await ref.read(getCurrentUserProvider)(NoParams());

    // La respuesta pertenece a un perfil que ya se abandonó: no se publica.
    if (_session.generation != generationAtStart) return null;

    // Sin red (o acceso revocado) mientras se actúa: se vuelve al tutor, nunca
    // se deja al dependiente en pantalla ni se restaura de caché (FP-50, FP-55).
    final actingFailure = _isActing ? result.fold((f) => f, (_) => null) : null;
    if (actingFailure != null &&
        (actingFailure is NetworkFailure || _isAccessRevoked(actingFailure))) {
      await _exitActing(
        notice:
            _isAccessRevoked(actingFailure) ? ActingNotice.accessRevoked : null,
      );
      return null;
    }

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
        final previous = state.valueOrNull;
        if (user != null) {
          _cacheUser(user);
        }
        state = AsyncValue.data(user);
        // Salir de una cuenta restringida (el paso 2 guardó la fecha): ahora el
        // servidor sí atiende el inbox, que no se pidió mientras duró.
        if ((previous?.isRestrictedAccount ?? false) &&
            !(user?.isRestrictedAccount ?? true)) {
          ref.read(unreadNotificationsCountProvider.notifier).refresh();
        }
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

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      if (failure is SocialSignInCancelledFailure) {
        AppLogger.i('Login social cancelado: $provider', tag: _tag);
        return SocialSignInResult.cancelled;
      }
      final errorMessage = failure is AuthFailure
          ? failure.message
          : 'errors.social_signin_failed'.tr(
              namedArgs: {'provider': provider == 'apple' ? 'Apple' : 'Google'},
            );
      AppLogger.w('Login social $provider falló: $errorMessage', tag: _tag);
      state = AsyncValue.error(errorMessage, StackTrace.current);
      return SocialSignInResult.failed;
    }

    // Igual que signIn(): la sesión solo vale si `/auth/me` responde.
    final loginUser = result.getOrElse(() => throw StateError('unreachable'));
    final session = await _confirmSessionAfterLogin(loginUser);
    if (session.error != null) {
      state = AsyncValue.error(session.error!, StackTrace.current);
      return SocialSignInResult.failed;
    }
    final user = session.user!;

    AppLogger.i('Login social exitoso: $provider', tag: _tag);
    ref
        .read(sharedPreferencesProvider)
        .setBool('user_manually_logged_out', false);
    _cacheUser(user);
    // Mismos efectos que signIn(): FCM y badge de notificaciones.
    _registerPush(user);
    ref.read(unreadNotificationsCountProvider.notifier).refresh();
    state = AsyncValue.data(user);
    return SocialSignInResult.success;
  }

  /// Cambia de perfil: `switchProfile('id')` actúa por ese dependiente y
  /// `switchProfile(null)` vuelve al tutor (FP-48).
  ///
  /// Orden: foto del tutor (para el selector), bandera `acting_dirty`, cambio de
  /// sesión + purga del estado en memoria en el MISMO tramo síncrono (así
  /// cualquier provider que se reconstruya ya sale con el perfil nuevo),
  /// purga de los cachés de disco y, solo entonces, `/auth/me` con el
  /// encabezado nuevo. Mientras carga el estado es `AsyncLoading`: ninguna vista
  /// conserva datos del perfil anterior.
  ///
  /// Un cambio posterior reemplaza a uno en vuelo (`superseded`). Nada del
  /// dependiente se escribe en disco y una falla de cualquier tipo devuelve al
  /// tutor.
  Future<SwitchProfileOutcome> switchProfile(
    String? dependentId, {
    String? firstName,
  }) async {
    if (dependentId == null) {
      if (!_isActing) return SwitchProfileOutcome.unchanged;
      await _exitActing();
      return SwitchProfileOutcome.exited;
    }
    if (dependentId == _session.dependentUserId) {
      return SwitchProfileOutcome.unchanged;
    }

    // Solo un `user` puede actuar por un menor. Un adolescente supervisado o un
    // teléfono vinculado jamás envía `X-Acting-For` (el servidor lo rechazaría
    // con 403 ACTING_FOR_FORBIDDEN): ni siquiera se entra en el modo.
    final kind = state.valueOrNull?.principal?.kind;
    if (kind != null && kind != PrincipalKind.user) {
      AppLogger.w('switchProfile rechazado: el principal no es un tutor',
          tag: _tag);
      return SwitchProfileOutcome.failed;
    }

    final epoch = ++_switchEpoch;

    // El tutor es quien está en `state` solo cuando aún no se actúa.
    if (!_isActing) {
      final guardian = state.valueOrNull;
      if (guardian == null || guardian.id == dependentId) {
        return SwitchProfileOutcome.failed;
      }
      ref.read(guardianUserProvider.notifier).state = guardian;
    }

    // La bandera se sube ANTES de que exista cualquier dato del dependiente.
    await _setActingDirty(true);
    if (epoch != _switchEpoch) return SwitchProfileOutcome.superseded;

    // Si ya se actuaba por otro dependiente, sus imágenes en disco se van.
    final leavingDependent = _isActing;

    // Mismo tramo síncrono: sesión nueva + purga en memoria + estado de carga.
    _session.enter(ActingDependent(userId: dependentId, firstName: firstName));
    purgeProfileScopeProviders(ref);
    state = const AsyncLoading();

    await purgeProfileScopeDiskCaches(
      ref,
      guardianUserId: ref.read(guardianUserProvider)?.id,
      clearImages: leavingDependent,
    );
    if (epoch != _switchEpoch) return SwitchProfileOutcome.superseded;

    final result = await ref.read(getCurrentUserProvider)(NoParams());
    if (epoch != _switchEpoch) return SwitchProfileOutcome.superseded;

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    final user = result.fold<UserEntity?>((_) => null, (u) => u);

    if (failure != null || user == null || user.id != dependentId) {
      final revoked = failure != null && _isAccessRevoked(failure);
      AppLogger.w(
        'No se pudo actuar por el dependiente (${failure?.message ?? 'respuesta inválida'})',
        tag: _tag,
      );
      await _exitActing(notice: revoked ? ActingNotice.accessRevoked : null);
      if (revoked) return SwitchProfileOutcome.accessRevoked;
      return failure is NetworkFailure
          ? SwitchProfileOutcome.offline
          : SwitchProfileOutcome.failed;
    }

    state = AsyncValue.data(user);
    ref.read(unreadNotificationsCountProvider.notifier).refresh();
    return SwitchProfileOutcome.entered;
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
  /// Retorna el resultado con el mensaje de error localizado y el código de
  /// negocio del backend (p. ej. `AUTH_DELETE_DEPENDENTS_ACK_REQUIRED`).
  Future<DeleteAccountResult> deleteAccountWithResult(
    DeleteAccountReauth reauth,
  ) async {
    AppLogger.i('Iniciando eliminación de cuenta', tag: _tag);

    // Confirmación biométrica antes de cualquier efecto destructivo
    // (no-op si el usuario no tiene biometría habilitada).
    final bioOk = await requireBiometricConfirmationRef(
      ref,
      reason: 'biometric.confirm_delete_account'.tr(),
    );
    if (!bioOk) {
      AppLogger.w('Delete account cancelado por biometría', tag: _tag);
      return DeleteAccountResult(
        errorMessage: 'auth.errors.operation_cancelled'.tr(),
      );
    }

    final result = await ref.read(authRepositoryProvider).deleteAccount(reauth);

    return result.fold<Future<DeleteAccountResult>>(
      (failure) async {
        final msg = failure is AuthFailure
            ? failure.message
            : 'auth.errors.delete_account_failed'.tr();
        AppLogger.w('Delete account fallido: $msg', tag: _tag);
        return DeleteAccountResult(
          errorMessage: msg,
          errorCode: failure.errorCode,
        );
      },
      (_) async {
        AppLogger.i('Cuenta eliminada correctamente', tag: _tag);

        // Solo en éxito: si el borrado falla el usuario sigue con sesión y
        // debe conservar las notificaciones push. El backend ya desactivó sus
        // tokens FCM en la cascada y los tokens de sesión ya se borraron, así
        // que solo se limpia el registro local: llamar al backend aquí daría
        // 401 y el interceptor expiraría la sesión a mitad de la UI.
        try {
          await ref
              .read(pushNotificationServiceProvider)
              .clearLocalRegistration();
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
        return const DeleteAccountResult.success();
      },
    );
  }

  /// Igual que [deleteAccountWithResult] pero solo devuelve el mensaje de error
  /// (`null` si se borró la cuenta).
  Future<String?> deleteAccount(DeleteAccountReauth reauth) async =>
      (await deleteAccountWithResult(reauth)).errorMessage;

  /// Proveedores sociales vinculados, para ofrecer la confirmación sin
  /// contraseña al borrar la cuenta. Lista vacía si la consulta falla.
  Future<List<SocialProvider>> connectedProviders() async {
    final result =
        await ref.read(authRepositoryProvider).getConnectedProviders();
    return result.fold((_) => const [], (list) => list);
  }

  /// Mínimo entre dos refrescos del modo disparados por 403
  /// `PRINCIPAL_SCOPE_DENIED`: una pantalla que dispara varias peticiones
  /// negadas no debe provocar una tormenta de `/auth/me`.
  static const Duration scopeDeniedRefreshInterval = Duration(seconds: 20);

  DateTime? _lastSupervisionRefresh;
  bool _refreshingSupervision = false;

  /// Vuelve a pedir `/auth/me` y publica el usuario SOLO si cambió el
  /// principal o el modo (p. ej. el director verificó el consentimiento: el
  /// adolescente pasa de pendiente a supervisado sin reiniciar la app).
  ///
  /// Solo actúa para una cuenta que no es adulta (adolescente supervisado, sin
  /// fecha de nacimiento o desconocida), nunca mientras se actúa por un
  /// menor ni durante una carga, y no sale de ningún modo "actuar por". Un
  /// fallo (sin red, 401...) no toca el estado. [minInterval] limita la
  /// frecuencia. Devuelve `true` si el estado cambió.
  Future<bool> refreshSupervision({Duration? minInterval}) async {
    final current = state.valueOrNull;
    if (current == null ||
        state.isLoading ||
        _isActing ||
        !current.isLimitedAccount ||
        _refreshingSupervision) {
      return false;
    }
    final last = _lastSupervisionRefresh;
    if (minInterval != null &&
        last != null &&
        DateTime.now().difference(last) < minInterval) {
      return false;
    }
    _lastSupervisionRefresh = DateTime.now();
    _refreshingSupervision = true;
    try {
      final generation = _session.generation;
      final result = await ref.read(getCurrentUserProvider)(NoParams());
      // El perfil o la sesión cambiaron mientras volaba: la respuesta es vieja.
      if (_session.generation != generation || state.isLoading) return false;
      final fresh = result.fold<UserEntity?>((_) => null, (u) => u);
      final still = state.valueOrNull;
      if (fresh == null || still == null || fresh.id != still.id) return false;
      final changed = fresh.principal != still.principal ||
          fresh.mode != still.mode ||
          fresh.legalAcceptancePending != still.legalAcceptancePending ||
          fresh.familyFeatures != still.familyFeatures;
      if (!changed) return false;
      AppLogger.i('Modo de la cuenta actualizado desde el servidor', tag: _tag);
      _cacheUser(fresh);
      state = AsyncValue.data(fresh);
      return true;
    } finally {
      _refreshingSupervision = false;
    }
  }

  /// Llamado por el interceptor ante 401 `AUTH_SUPERVISED_ACCESS_REVOKED`: el
  /// tutor cortó el acceso del menor (desactivó, restableció, congeló).
  ///
  /// Deja el aviso para el login y cierra la sesión local igual que una sesión
  /// expirada: [expireSession] borra el almacenamiento seguro y pone el estado
  /// en `null`, y el router purga el registro de perfil y los cachés de disco
  /// al ver el cierre. Sin llamadas a la API: el token ya no vale.
  void onSupervisedAccessRevoked() {
    ref.read(loginNoticeProvider.notifier).state =
        LoginNotice.supervisedAccessRevoked;
    expireSession();
  }

  /// Alinea la bandera `session_mode` con lo que el servidor dice de esta
  /// sesión (`/auth/me.principal.kind` es la autoridad).
  ///
  /// - `linked_device`: la bandera pasa a `device`.
  /// - Cualquier otro principal: la bandera se borra.
  /// - Sin principal con la bandera en `device`: el servidor no confirma que
  ///   sea un teléfono vinculado ni una cuenta, así que falla cerrado como
  ///   principal desconocido (cuenta restringida: solo «Cerrar sesión»).
  UserEntity _reconcileSessionMode(UserEntity user, SessionMode persisted) {
    final kind = user.principal?.kind;
    final modeState = ref.read(sessionModeProvider.notifier);
    if (kind == PrincipalKind.linkedDevice) {
      if (persisted != SessionMode.device) {
        unawaited(_sessionModeStore.write(SessionMode.device));
      }
      modeState.state = SessionMode.device;
      return user;
    }
    if (kind == null && persisted == SessionMode.device) {
      AppLogger.w('Bandera de dispositivo sin principal: falla cerrado',
          tag: _tag);
      modeState.state = SessionMode.device;
      return user
          .withPrincipal(const PrincipalInfo(kind: PrincipalKind.unknown));
    }
    if (persisted == SessionMode.device) {
      unawaited(_sessionModeStore.clear());
    }
    modeState.state = SessionMode.account;
    return user;
  }

  /// Vincula este teléfono como dispositivo de un menor (FP3-42, FP3-52).
  ///
  /// Solo con la app SIN sesión (ni de cuenta ni de dispositivo). Devuelve
  /// `null` si todo salió bien (el router lleva al inicio del dispositivo) o el
  /// mensaje traducido por `errorCode` para mostrar en la pantalla.
  ///
  /// Orden: purga defensiva de todo estado de perfil por el CONTENEDOR (nunca
  /// `Ref.invalidate`, que lanza `CircularDependencyError`) > canje del token >
  /// tokens + bandera de modo > `/auth/me`. Si `/auth/me` falla NO queda una
  /// sesión a medias: se cierra la sesión recién creada (tokens, bandera y
  /// cachés locales) y se muestra el error. No pasa por `AsyncLoading`: el
  /// router mandaría a splash y desmontaría la pantalla de vinculación.
  Future<String?> pairDevice(DevicePairingInput input) async {
    if (_isActing ||
        state.isLoading ||
        state.valueOrNull != null ||
        await ref.read(authRepositoryProvider).hasLocalToken()) {
      AppLogger.w('Vinculación rechazada: ya hay una sesión', tag: _tag);
      return 'device.pair.errors.session_exists'.tr();
    }

    // Purga defensiva ANTES de que exista cualquier dato del menor.
    purgeProfileScopeProviders(ref);
    await purgeProfileScopeDiskCaches(
      ref,
      guardianUserId: null,
      clearImages: true,
    );

    final result = await ref.read(pairDeviceUseCaseProvider)(input);
    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      AppLogger.w('Vinculación fallida (${failure.errorCode ?? failure.code})',
          tag: _tag);
      // 5 intentos por minuto por IP: un 429 sin código es «demasiados
      // intentos», no un fallo genérico.
      return userErrorMessage(
        failure,
        fallbackKey: failure.code == 429
            ? 'errors.too_many_attempts'
            : 'device.pair.errors.generic',
      );
    }
    final paired = result.getOrElse(() => throw StateError('unreachable'));

    // Tokens y bandera, juntos. Si algo de esto falla se deshace todo.
    final secureStorage = ref.read(secureStorageProvider);
    try {
      await secureStorage.write(AppConstants.tokenKey, paired.accessToken);
      await secureStorage.write(
          AppConstants.refreshTokenKey, paired.refreshToken);
      final expiresAt = paired.expiresAt;
      if (expiresAt != null) {
        await secureStorage.write(
            AppConstants.expiresAtKey, expiresAt.toString());
      }
      final tokenType = paired.tokenType;
      if (tokenType != null) {
        await secureStorage.write(AppConstants.tokenTypeKey, tokenType);
      }
      await _sessionModeStore.write(SessionMode.device);
    } catch (e) {
      AppLogger.e('No se pudo guardar la sesión del dispositivo',
          tag: _tag, error: e.runtimeType);
      return _abortPairing(null);
    }
    ref.read(sessionModeProvider.notifier).state = SessionMode.device;

    final me = await ref.read(getCurrentUserProvider)(NoParams());
    final meFailure = me.fold<Failure?>((f) => f, (_) => null);
    final user = me.fold<UserEntity?>((_) => null, (u) => u);
    if (meFailure != null ||
        user == null ||
        user.principal?.kind != PrincipalKind.linkedDevice) {
      AppLogger.w(
        'Vinculación correcta pero /auth/me falló '
        '(${meFailure?.errorCode ?? meFailure?.code ?? 'sin usuario'}); '
        'se deshace',
        tag: _tag,
      );
      return _abortPairing(meFailure);
    }

    AppLogger.i('Dispositivo vinculado', tag: _tag);
    ref.read(deviceNoticeProvider.notifier).state = null;
    ref
        .read(sharedPreferencesProvider)
        .setBool('user_manually_logged_out', false);
    // Un teléfono vinculado guarda lo mínimo para restaurarse sin red.
    _cacheUser(user);
    // El token FCM del teléfono se registra con `push:register`.
    _registerPush(user);
    ref.read(unreadNotificationsCountProvider.notifier).refresh();
    state = AsyncValue.data(user);
    return null;
  }

  /// Deshace una vinculación a medias: cierra la sesión recién creada (en el
  /// servidor, si responde) y borra tokens, bandera y estado local. Devuelve el
  /// mensaje a mostrar.
  Future<String?> _abortPairing(Failure? failure) async {
    try {
      await ref.read(signOutProvider)(NoParams());
    } catch (_) {}
    await _sessionModeStore.clear();
    ref.read(sessionModeProvider.notifier).state = SessionMode.account;
    ref.read(unreadNotificationsCountProvider.notifier).setZero();
    purgeProfileScopeProviders(ref);
    return userErrorMessage(
      failure,
      fallbackKey: 'device.pair.errors.session_load_failed',
    );
  }

  /// Llamado por el interceptor ante 401 `AUTH_DEVICE_REVOKED` /
  /// `AUTH_DEVICE_SESSION_EXPIRED` o un refresh muerto en modo dispositivo: el
  /// tutor desvinculó el teléfono, dejó de ser elegible o la vinculación llegó
  /// a su tope (FP3-52).
  ///
  /// Deja el aviso para la pantalla de vinculación y cierra la sesión local
  /// igual que una sesión expirada ([expireSession] borra los cachés y el router
  /// purga el registro de perfil y los cachés de disco al ver el cierre). Sin
  /// llamadas a la API: el token ya no vale. Nada queda en cola: el teléfono no
  /// tiene cola de subidas.
  void onDeviceUnpaired({DeviceNotice notice = DeviceNotice.unpaired}) {
    ref.read(deviceNoticeProvider.notifier).state = notice;
    unawaited(
      ref.read(pushNotificationServiceProvider).clearLocalRegistration(),
    );
    expireSession();
  }

  /// Called by AuthInterceptor when the refresh token is dead.
  ///
  /// Clears all local tokens and cached PII then sets state to null so
  /// GoRouter redirects to login. Does NOT make any API calls (logout
  /// endpoint, FCM unregister) because the tokens are already invalid.
  void expireSession() {
    AppLogger.w('Sesión expirada por interceptor, limpiando estado local',
        tag: _tag);
    _clearActingForLogout();
    _endSessionMode();

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

  /// La sesión terminó: ni el modo en memoria ni la bandera del almacenamiento
  /// seguro sobreviven.
  void _endSessionMode() {
    ref.read(sessionModeProvider.notifier).state = SessionMode.account;
    unawaited(_sessionModeStore.clear());
  }

  /// Cerrar sesión
  Future<bool> signOut() async {
    // El modo "actuar por" se cierra ANTES de tocar la sesión (FP-53): ninguna
    // petición posterior debe llevar el encabezado de un dependiente.
    _clearActingForLogout();
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
        _endSessionMode();
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
