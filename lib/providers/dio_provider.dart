import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/acting_for_session.dart';
import '../core/auth/session_mode.dart';
import '../core/network/dio_client.dart';
import '../core/network/interceptors/authorization_stale_interceptor.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/device_mode/presentation/providers/device_notice_provider.dart';

/// Crea un Dio de la app con TODOS los callbacks de sesión cableados:
/// refresh muerto -> cerrar sesión, y 403 `ACTING_FOR_FORBIDDEN` -> salir del
/// perfil del menor.
///
/// Cualquier Dio propio de una feature (credencial virtual, QR) debe crearse
/// con esto y no con `DioClient.createDio` a pelo: sin los callbacks, un acceso
/// revocado o una sesión expirada en esas peticiones no haría nada (S3).
Dio buildAppDio(Ref ref) {
  final dio = DioClient.createDio(
    onAuthExpired: () =>
        ref.read(authNotifierProvider.notifier).expireSession(),
    onSupervisedAccessRevoked: () =>
        ref.read(authNotifierProvider.notifier).onSupervisedAccessRevoked(),
    onDeviceUnpaired: (sessionExpired) =>
        ref.read(authNotifierProvider.notifier).onDeviceUnpaired(
              notice: sessionExpired
                  ? DeviceNotice.sessionExpired
                  : DeviceNotice.unpaired,
            ),
    isDeviceSession: () => ref.read(sessionModeProvider) == SessionMode.device,
    onPrincipalScopeDenied: () => unawaited(
      ref.read(authNotifierProvider.notifier).refreshSupervision(
            minInterval: AuthNotifier.scopeDeniedRefreshInterval,
          ),
    ),
    actingForSession: ref.read(actingForSessionProvider),
    onActingForbidden: (dependentUserId) => ref
        .read(authNotifierProvider.notifier)
        .onActingForbidden(dependentUserId),
  );
  // Primero de todos: una mutación con la autorización de la caché (sesión
  // restaurada sin red) no sale de la app. Solo lee el estado; nunca cambia el
  // modo «actuar por» ni el principal.
  dio.interceptors.insert(
    0,
    AuthorizationStaleInterceptor(
      isStale: () =>
          ref.read(authNotifierProvider).value?.authorizationStale ?? false,
    ),
  );
  return dio;
}

/// Provider para la instancia configurada de Dio
final dioProvider = Provider<Dio>(buildAppDio);
