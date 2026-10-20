import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import 'posthog_analytics.dart';

/// Lo que la política necesita de la analítica real. Se sustituye en tests.
abstract class AnalyticsGateway {
  /// ¿Ya se identificó a alguien en este teléfono?
  bool get hasIdentifiedUser;

  Future<void> identify(String userId);

  Future<void> reset();

  /// Teléfono de un menor: PostHog deja de capturar por completo.
  Future<void> disableForDevice();

  /// El teléfono dejó de ser un dispositivo vinculado: se reactiva la captura.
  Future<void> enableAfterDevice();

  /// ¿Se bloqueó la analítica por ser un teléfono vinculado?
  bool get blockedForDevice;
}

/// [AnalyticsGateway] sobre PostHog.
class PosthogAnalyticsGateway implements AnalyticsGateway {
  const PosthogAnalyticsGateway();

  @override
  bool get hasIdentifiedUser => analyticsUserIdentified;

  @override
  Future<void> identify(String userId) => identifyAnalyticsUser(userId);

  @override
  Future<void> reset() => resetAnalyticsUser();

  @override
  Future<void> disableForDevice() => disableAnalyticsForDevice();

  @override
  Future<void> enableAfterDevice() => enableAnalyticsAfterDevice();

  @override
  bool get blockedForDevice => analyticsBlockedForDevice;
}

/// Quién puede identificarse en analítica (FP3-30, privacidad §6.1).
///
/// - Adulto con `analytics_anonymous == false` explícito: se identifica como
///   hasta ahora.
/// - Adolescente supervisado (pendiente o con tutor), teléfono vinculado,
///   campo ausente o desconocido, usuario no cargado: JAMÁS se identifica
///   (falla cerrado). Los eventos anónimos siguen permitidos.
/// - Si este teléfono ya había identificado a otra persona y ahora la sesión
///   es anónima, se hace `reset()` para que los eventos del menor no queden
///   atados a la identidad anterior.
/// - Mientras un tutor actúa por un menor la analítica se queda como está: ni
///   se identifica al menor ni se toca la identidad del tutor.
/// - Teléfono vinculado de un menor de 13: PostHog se DESACTIVA por completo
///   (`disable`): ni identify, ni eventos, ni pantallas (privacidad §6.1). Al
///   dejar de serlo (login de cuenta tras desvincular) se reactiva.
class AnalyticsPolicy {
  const AnalyticsPolicy({
    this.gateway = const PosthogAnalyticsGateway(),
  });

  final AnalyticsGateway gateway;

  /// Aplica la política a [user]. Nunca lanza: la analítica no puede romper el
  /// inicio de sesión.
  Future<void> apply(UserEntity? user, {bool acting = false}) async {
    if (user == null || acting) return;
    try {
      if (user.isLinkedDevice) {
        await gateway.disableForDevice();
        return;
      }
      if (gateway.blockedForDevice) {
        await gateway.enableAfterDevice();
      }
      if (user.canIdentifyInAnalytics) {
        await gateway.identify(user.id);
      } else if (gateway.hasIdentifiedUser) {
        await gateway.reset();
      }
    } catch (_) {
      // Mejor sin analítica que sin sesión.
    }
  }
}

/// Política vigente. `Provider` simple y sin estado propio: los tests
/// sustituyen la pasarela.
final analyticsPolicyProvider = Provider<AnalyticsPolicy>(
  (ref) => const AnalyticsPolicy(),
);
