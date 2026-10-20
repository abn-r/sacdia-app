import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/domain/utils/authorization_utils.dart';
import 'acting_route_policy.dart';
import 'pastor_route_access.dart';
import 'supervised_route_policy.dart';

/// Un destino (push tocado, enlace) que llegó cuando el router aún no podía
/// recibirlo: la sesión o el arranque seguían cargando y el redirect lo habría
/// descartado mandándolo a splash (lección de la Fase 2).
class PendingNavigation extends Equatable {
  /// Ruta ya validada contra la lista de rutas permitidas de la notificación.
  final String route;

  /// `true` si se abre con `go` (pestañas del shell); `false` con `push`.
  final bool replace;

  const PendingNavigation({required this.route, this.replace = false});

  @override
  List<Object?> get props => [route, replace];
}

/// Destino diferido. NO es estado de perfil: lo escribe quien recibe el push
/// mientras la app carga y lo consume el router una vez que la sesión está
/// lista; al cerrar sesión se descarta (un push de la persona anterior nunca
/// se entrega a la siguiente).
final pendingNavigationProvider = StateProvider<PendingNavigation?>(
  (ref) => null,
);

/// ¿Puede entregarse [route] a [user] ahora que la sesión está lista?
///
/// Aplica la misma política que el redirect del router para el modo vigente:
/// un destino que el redirect enviaría a otra parte se descarta en lugar de
/// abrirse un instante y rebotar. [acting]: se actúa por un menor.
bool isPendingNavigationAllowed({
  required UserEntity user,
  required String route,
  required bool acting,
}) {
  final path = Uri.tryParse(route)?.path ?? route;
  // El gate legal y el post-registro son dueños de la pantalla hasta terminar.
  if (userNeedsLegalAcceptance(user)) return false;
  if (userNeedsPostRegistration(user)) return false;
  if (acting && isBlockedWhileActing(path)) return false;
  if (isPastorWithoutClub(user) && !isPastorAllowedPath(path)) return false;
  return supervisedRouteRedirect(
        mode: user.mode,
        path: path,
        needsPostRegistration: false,
      ) ==
      null;
}
