import '../../../../core/config/route_names.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../notifications/domain/entities/notification_item.dart';
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

/// Sección de club a la que apunta una notificación de la bandeja.
///
/// El historial trae `target_id` = id de la sección de club cuando el destino
/// es `club_section` o `section_role`. En cualquier otro tipo (o en un servidor
/// anterior que no manda el campo) no hay sección: `null`.
int? clubSectionIdOfInboxTarget({
  required NotificationTargetType targetType,
  String? targetId,
}) {
  if (targetType != NotificationTargetType.club &&
      targetType != NotificationTargetType.sectionRole) {
    return null;
  }
  return int.tryParse(targetId?.trim() ?? '');
}

/// Dónde abrir las solicitudes de ingreso y, si hace falta, a qué asignación
/// cambiar antes.
class MemberRequestsDestination {
  const MemberRequestsDestination(this.route, {this.switchToAssignmentId});

  final String route;

  /// Asignación de club que debe volverse la activa antes de navegar. `null` =
  /// se abre el contexto actual sin cambiar nada.
  final String? switchToAssignmentId;
}

/// Destino de una solicitud de ingreso con su sección ([clubSectionId], del
/// aviso: `target_id` en la bandeja, `data.clubSectionId` en el push).
///
/// - Sin sección, o la misma que la del contexto activo: comportamiento de
///   siempre ([memberRequestsRouteFor]) sobre el contexto actual.
/// - Otra sección: se cambia a ella SOLO si el usuario tiene una asignación
///   activa en esa sección cuyo rol permite ver solicitudes. Sin asignación (o
///   sin permiso en ella) se conserva el comportamiento de siempre: nunca se
///   escala a una sección que el usuario no tiene.
MemberRequestsDestination? memberRequestsDestinationFor(
  UserEntity? user, {
  int? clubSectionId,
}) {
  final current = memberRequestsRouteFor(user);
  final currentDestination =
      current == null ? null : MemberRequestsDestination(current);

  final authorization = user?.authorization;
  if (clubSectionId == null || authorization == null) {
    return currentDestination;
  }
  if (authorization.activeGrant?.sectionId == clubSectionId) {
    return currentDestination;
  }

  for (final grant in authorization.clubAssignments) {
    final assignmentId = grant.assignmentId;
    if (assignmentId == null ||
        grant.sectionId != clubSectionId ||
        !grant.isActive ||
        !grantCanReviewJoinRequests(grant)) {
      continue;
    }
    return MemberRequestsDestination(
      RouteNames.homeMemberRequests,
      switchToAssignmentId: assignmentId,
    );
  }
  return currentDestination;
}

/// Resuelve la ruta de las solicitudes y, si el aviso es de otra sección con
/// asignación del usuario, cambia primero el contexto activo con
/// [switchContext] (el mismo mecanismo del selector de sección). Si el cambio
/// falla se cae al contexto actual. Devuelve `null` si no hay destino.
Future<String?> resolveMemberRequestsRoute({
  required UserEntity? Function() readUser,
  required Future<bool> Function(String assignmentId) switchContext,
  int? clubSectionId,
}) async {
  final destination = memberRequestsDestinationFor(
    readUser(),
    clubSectionId: clubSectionId,
  );
  if (destination == null) return null;

  final assignmentId = destination.switchToAssignmentId;
  if (assignmentId == null) return destination.route;

  var switched = false;
  try {
    switched = await switchContext(assignmentId);
  } catch (_) {
    switched = false;
  }
  if (switched) return destination.route;
  return memberRequestsRouteFor(readUser());
}

/// Modo inicial de la pantalla de Miembros para el query `tab` de su ruta.
int membersInitialModeForTab(String? tab) =>
    tab?.trim().toLowerCase() == membersRequestsTab ? membersRequestsMode : 0;
