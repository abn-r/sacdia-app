import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/domain/utils/authorization_utils.dart';
import 'pastor_route_access.dart';
import 'route_names.dart';

/// Rutas que puede abrir un coordinador sin club (ver `isCoordinatorWithoutClub`).
///
/// Su inicio es `/home/dashboard`, que dibuja el panel de coordinación
/// (`CoordinatorHubView`). Además del panel y de sus submódulos (clubes
/// asignados, revisión de evidencias, fichas de consentimiento, reportes SLA),
/// puede abrir su perfil, la bandeja de notificaciones y «Mi familia» (se
/// llega desde el perfil, si además es tutor). Quedan fuera las pestañas y
/// pantallas de un miembro de club: honores, clases, clubes propios, miembros,
/// actividades de club, investiduras propias, etc. Editar el perfil, los
/// ajustes y cerrar sesión se abren con `Navigator.push` desde el perfil, así
/// que no pasan por el router.
const Set<String> _coordinatorExactPaths = {
  RouteNames.homeDashboard,
  RouteNames.homeProfile,
  RouteNames.homeMedicalInfo,
  RouteNames.notificationsInbox,
  RouteNames.coordinatorProfile,
};

/// Subárboles completos: el panel (`/coordinator/...`) y Mi familia
/// (`/family/...`).
const List<String> _coordinatorPrefixes = [
  RouteNames.coordinator,
  RouteNames.family,
];

/// `/coordinator/coord-activities` muestra las actividades de un club: sin club
/// no hay nada que listar.
const Set<String> _coordinatorBlockedPaths = {
  RouteNames.coordinatorActivities,
};

/// ¿Puede el coordinador sin club abrir [path]? (ruta ya resuelta, sin query).
bool isCoordinatorAllowedPath(String path) {
  final normalized = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  if (_coordinatorBlockedPaths.contains(normalized)) return false;
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
/// pastor sin club que no coordina vuelve al listado de autorizaciones.
String? clubLessRouteRedirect(UserEntity? user, String path) {
  if (isCoordinatorWithoutClub(user)) {
    if (isCoordinatorAllowedPath(path)) return null;
    if (isPastorWithoutClub(user) && isPastorAllowedPath(path)) return null;
    return RouteNames.homeDashboard;
  }
  if (isPastorWithoutClub(user) && !isPastorAllowedPath(path)) {
    return RouteNames.investitureAuthorize;
  }
  return null;
}
