import 'route_names.dart';

/// Rutas a las que NO se puede entrar mientras se actúa por un dependiente
/// (FP-56). Mi familia se gestiona desde el perfil propio del tutor.
///
/// Ajustes de seguridad, sesiones, exportación y borrado de cuenta no son rutas
/// de `go_router` sino pantallas empujadas desde Ajustes: allí se ocultan sus
/// entradas leyendo `actingDependentProvider`.
///
/// `RouteNames.accessDenied` (destino del guard de rutas por catálogo) nunca se
/// bloquea: mientras se actúa, la autorización evaluada es la del menor.
bool isBlockedWhileActing(String path) {
  if (path == RouteNames.accessDenied) return false;
  return path == RouteNames.family || path.startsWith('${RouteNames.family}/');
}
