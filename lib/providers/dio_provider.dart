import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/acting_for_session.dart';
import '../core/network/dio_client.dart';
import '../features/auth/presentation/providers/auth_providers.dart';

/// Crea un Dio de la app con TODOS los callbacks de sesión cableados:
/// refresh muerto -> cerrar sesión, y 403 `ACTING_FOR_FORBIDDEN` -> salir del
/// perfil del menor.
///
/// Cualquier Dio propio de una feature (credencial virtual, QR) debe crearse
/// con esto y no con `DioClient.createDio` a pelo: sin los callbacks, un acceso
/// revocado o una sesión expirada en esas peticiones no haría nada (S3).
Dio buildAppDio(Ref ref) {
  return DioClient.createDio(
    onAuthExpired: () =>
        ref.read(authNotifierProvider.notifier).expireSession(),
    onSupervisedAccessRevoked: () =>
        ref.read(authNotifierProvider.notifier).onSupervisedAccessRevoked(),
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
}

/// Provider para la instancia configurada de Dio
final dioProvider = Provider<Dio>(buildAppDio);
