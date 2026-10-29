import '../../../../core/config/route_names.dart';
import '../../../auth/domain/entities/user_entity.dart';
import 'consent_access.dart';

/// `data.type` del push que el backend envía a los revisores cuando llega una
/// solicitud de ingreso (también la de un menor con consentimiento pendiente).
const String membershipRequestPushType = 'membership_request_created';

/// Valor de `tab` con el que la pantalla de Miembros abre la pestaña
/// Solicitudes.
const String membersRequestsTab = 'requests';

/// Índice del modo Solicitudes en la pantalla de Miembros.
const int membersRequestsMode = 1;

/// ¿La notificación de la bandeja es una solicitud de ingreso?
///
/// El historial guarda `source: membership_requests:new_request` (tanto la que
/// envía el servicio de solicitudes como el aviso de un menor dado de alta por
/// el director). Se acepta cualquier hermano del prefijo.
bool isMembershipRequestSource(String? source) {
  final normalized = source?.trim().toLowerCase() ?? '';
  return normalized.startsWith('membership_requests:');
}

/// ¿El push es el aviso de una solicitud de ingreso nueva?
bool isMembershipRequestPushType(String? type) =>
    type?.trim() == membershipRequestPushType;

/// Destino de una solicitud de ingreso para [user]: Miembros en la pestaña
/// Solicitudes, o `null` si no puede verlas (ni `club_members:approve` ni
/// `consent:verify` de club). Sin destino la notificación solo se informa.
String? memberRequestsRouteFor(UserEntity? user) {
  if (joinRequestsAccess(user) == JoinRequestsAccess.none) return null;
  return RouteNames.homeMemberRequests;
}

/// Modo inicial de la pantalla de Miembros para el query `tab` de su ruta.
int membersInitialModeForTab(String? tab) =>
    tab?.trim().toLowerCase() == membersRequestsTab ? membersRequestsMode : 0;
