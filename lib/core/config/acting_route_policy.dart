import 'route_names.dart';

/// Rutas a las que NO se puede entrar mientras se actúa por un dependiente
/// (FP-56). Mi familia y las constancias de servicio se gestionan desde el
/// perfil propio de la persona.
///
/// Ajustes de seguridad, sesiones, exportación y borrado de cuenta no son rutas
/// de `go_router` sino pantallas empujadas desde Ajustes: allí se ocultan sus
/// entradas leyendo `actingDependentProvider`.
///
/// `RouteNames.accessDenied` (destino del guard de rutas por catálogo) nunca se
/// bloquea: mientras se actúa, la autorización evaluada es la del menor.
bool isBlockedWhileActing(String path) {
  if (path == RouteNames.accessDenied) return false;
  return _hasPrefix(path, RouteNames.family) ||
      _hasPrefix(path, RouteNames.serviceCredentials) ||
      // Fase 4: la liberación y el canje del código son de la propia persona.
      _hasPrefix(path, RouteNames.release) ||
      _hasPrefix(path, RouteNames.adultClaim);
}

bool _hasPrefix(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');
