import 'route_names.dart';

/// Rutas a las que NO se puede entrar mientras se actúa por un dependiente
/// (FP-56). Mi familia se gestiona desde el perfil propio del tutor.
///
/// Ajustes de seguridad, sesiones, exportación y borrado de cuenta no son rutas
/// de `go_router` sino pantallas empujadas desde Ajustes: allí se ocultan sus
/// entradas leyendo `actingDependentProvider`.
bool isBlockedWhileActing(String path) {
  return path == RouteNames.family || path.startsWith('${RouteNames.family}/');
}
