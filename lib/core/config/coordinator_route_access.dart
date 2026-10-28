import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/domain/utils/authorization_utils.dart';
import 'pastor_route_access.dart';
import 'route_names.dart';

/// Rutas que puede abrir un coordinador sin club (ver `isCoordinatorWithoutClub`).
///
/// Su inicio es `/home/dashboard`, que dibuja el panel de coordinación
/// (`CoordinatorHubView`). Además del panel y de sus submódulos (clubes
/// asignados, revisión de evidencias, fichas de consentimiento, tiempo de
/// respuesta SLA y reportes de club), puede abrir su perfil, la bandeja de
/// notificaciones y «Mi familia» (se llega desde el perfil, si además es
/// tutor). Quedan fuera las pestañas y pantallas de un miembro de club:
/// honores, clases, clubes propios, miembros, actividades de club, investiduras
/// propias, etc. Editar el perfil, los ajustes y cerrar sesión se abren con
/// `Navigator.push` desde el perfil, así que no pasan por el router.
const Set<String> _coordinatorExactPaths = {
  RouteNames.homeDashboard,
  RouteNames.homeProfile,
  RouteNames.homeMedicalInfo,
  RouteNames.notificationsInbox,
  // Panel de coordinación y sus pantallas, una a una: no hay prefijo
  // `/coordinator/...` abierto, así una ruta retirada (actividades, perfil de
  // coordinador, aprobaciones de camporee) no se cuela por él.
  RouteNames.coordinator,
  RouteNames.coordinatorClubs,
  RouteNames.coordinatorSla,
  RouteNames.coordinatorReports,
  RouteNames.coordinatorEvidenceReview,
  RouteNames.coordinatorConsentReview,
};

/// Subárboles completos: el detalle de evidencia
/// (`/coordinator/evidence-review/:type/:id`) y Mi familia (`/family/...`).
const List<String> _coordinatorPrefixes = [
  RouteNames.coordinatorEvidenceReview,
  RouteNames.family,
];

/// ¿Puede el coordinador sin club abrir [path]? (ruta ya resuelta, sin query).
bool isCoordinatorAllowedPath(String path) {
  final normalized = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  if (_coordinatorExactPaths.contains(normalized)) return true;
  return _coordinatorPrefixes.any(
    (prefix) => normalized == prefix || normalized.startsWith('$prefix/'),
  );
}

/// Destino al que se manda a [user] si [path] está fuera de su alcance sin
/// club, o `null` si puede abrirla (o si no es un usuario sin club).
///
/// Un coordinador sin club vuelve a su inicio (el panel de coordinación). Si
/// además es pastor sin club, conserva también las rutas de «Autorizaciones»
/// (se llega por notificación o enlace; su inicio es la coordinación). Un
/// pastor sin club que no coordina vuelve a su inicio (`/home/dashboard`, que
/// dibuja el listado de autorizaciones dentro de las pestañas).
String? clubLessRouteRedirect(UserEntity? user, String path) {
  if (isCoordinatorWithoutClub(user)) {
    if (isCoordinatorAllowedPath(path)) return null;
    if (isPastorWithoutClub(user) && isPastorAllowedPath(path)) return null;
    return RouteNames.homeDashboard;
  }
  // Home, not `/investiture/authorize`: that route sits outside the tab
  // shell, so a redirect there left the pastor with no tabs and no way back.
  if (isPastorWithoutClub(user) && !isPastorAllowedPath(path)) {
    return RouteNames.homeDashboard;
  }
  return null;
}
