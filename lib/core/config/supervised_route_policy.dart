import '../../features/auth/domain/entities/principal_info.dart';
import 'device_route_policy.dart';
import 'route_names.dart';

/// Rutas de `go_router` que un adolescente supervisado puede abrir (FP3-31,
/// FP3-32). Complementa a `acting_route_policy.dart`.
///
/// - **Pendiente de tutor** (`AccountMode.teenPending`): LISTA BLANCA. Solo su
///   pantalla de estado, el post-registro (pasos 1-3 crean la solicitud de club
///   que el director verificará), la aceptación legal y lo que cuelga de ellas.
///   Todo lo demás (también `/home/*`) vuelve a su pantalla.
/// - **Con tutor verificado** (`AccountMode.teenSupervised`): LISTA NEGRA. La
///   app de miembro completa, salvo Mi familia y las pantallas de cuenta
///   sensibles. Sesiones, exportación de datos y borrado de cuenta no son rutas
///   de `go_router` sino pantallas empujadas desde Ajustes: sus entradas se
///   ocultan leyendo el modo (ver `settings_view.dart`). Los prefijos de abajo
///   cubren además cualquier ruta nueva que se publique con ese nombre.
///
/// - **Sin fecha de nacimiento** (`AccountMode.profileIncomplete`): LISTA
///   BLANCA mínima. Solo el post-registro (el paso 2 guarda la fecha y el
///   servidor cambia el modo) y la aceptación legal. Todo lo demás vuelve al
///   post-registro, aunque la bandera local diga que ya terminó: el servidor
///   decide cuándo se levanta la restricción.
/// - **Principal desconocido** (`AccountMode.restricted`): falla cerrado. Solo
///   su pantalla informativa y la aceptación legal.
///
/// El servidor es la autoridad: esto solo evita pantallas que acabarían en 403.

/// Pestaña/pantalla que un adolescente pendiente puede abrir sin más.
const Set<String> _pendingAllowedExact = {
  RouteNames.teenPendingHome,
  RouteNames.postRegistration,
  RouteNames.legalAcceptance,
};

/// Lo único que abre una cuenta sin fecha de nacimiento.
const Set<String> _profileIncompleteAllowedExact = {
  RouteNames.postRegistration,
  RouteNames.legalAcceptance,
};

/// Lo único que abre una cuenta con un principal desconocido.
const Set<String> _restrictedAllowedExact = {
  RouteNames.restrictedAccount,
  RouteNames.legalAcceptance,
};

/// Prefijos vetados para un adolescente supervisado (sesión activa del tutor).
const List<String> kSupervisedBlockedPrefixes = [
  RouteNames.family,
  '/security',
  '/sessions',
  '/mfa',
  '/delete-account',
  '/data-export',
];

String _normalize(String path) => path.length > 1 && path.endsWith('/')
    ? path.substring(0, path.length - 1)
    : path;

bool _hasPrefix(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

/// ¿Puede un adolescente SIN tutor verificado abrir [path]?
bool isAllowedForPendingTeen(String path) =>
    _pendingAllowedExact.contains(_normalize(path));

/// ¿Está vetado [path] para un adolescente CON tutor verificado?
bool isBlockedForActiveTeen(String path) {
  final normalized = _normalize(path);
  return kSupervisedBlockedPrefixes.any((p) => _hasPrefix(normalized, p));
}

/// ¿Puede una cuenta SIN fecha de nacimiento abrir [path]?
bool isAllowedForProfileIncomplete(String path) =>
    _profileIncompleteAllowedExact.contains(_normalize(path));

/// ¿Puede una cuenta con un principal desconocido abrir [path]?
bool isAllowedForRestricted(String path) =>
    _restrictedAllowedExact.contains(_normalize(path));

/// Pantalla de estado del modo restringido (no es un destino para nadie más).
bool isTeenOnlyRoute(String path) =>
    _normalize(path) == RouteNames.teenPendingHome;

/// Cáscara del teléfono vinculado (`/device/*`, salvo la pantalla de
/// vinculación): no es un destino para ninguna cuenta.
bool isDeviceOnlyRoute(String path) {
  final normalized = _normalize(path);
  return normalized != RouteNames.devicePair &&
      _hasPrefix(normalized, '/device');
}

/// Pantalla informativa de la cuenta desconocida (no es un destino para nadie
/// más).
bool isRestrictedOnlyRoute(String path) =>
    _normalize(path) == RouteNames.restrictedAccount;

/// Destino «de inicio» de una cuenta según su [mode]: lo que sustituye al
/// inicio de los adultos.
String accountHomeFor(AccountMode mode, {required bool needsPostRegistration}) {
  switch (mode) {
    case AccountMode.profileIncomplete:
      return RouteNames.postRegistration;
    case AccountMode.restricted:
      return RouteNames.restrictedAccount;
    case AccountMode.linkedDevice:
      return deviceHomeFor(
        legalPending: false,
        needsRegistration: needsPostRegistration,
      );
    case AccountMode.teenPending:
      return needsPostRegistration
          ? RouteNames.postRegistration
          : RouteNames.teenPendingHome;
    case AccountMode.adult:
    case AccountMode.teenSupervised:
      return needsPostRegistration
          ? RouteNames.postRegistration
          : RouteNames.homeDashboard;
  }
}

/// A dónde llevar al usuario según su [mode] y la ruta [path] a la que va, o
/// `null` si puede seguir.
///
/// [needsPostRegistration]: el adolescente pendiente aún no terminó los pasos
/// 1-3; esos pasos son su destino (no la pantalla de estado, que solo tiene
/// sentido cuando ya hay una solicitud de club que verificar).
String? supervisedRouteRedirect({
  required AccountMode mode,
  required String path,
  required bool needsPostRegistration,
}) {
  switch (mode) {
    case AccountMode.adult:
      // Las pantallas de estado no existen para un adulto (p. ej. cumplió 18).
      return isTeenOnlyRoute(path) ||
              isRestrictedOnlyRoute(path) ||
              isDeviceOnlyRoute(path)
          ? RouteNames.homeDashboard
          : null;
    case AccountMode.profileIncomplete:
      return isAllowedForProfileIncomplete(path)
          ? null
          : RouteNames.postRegistration;
    case AccountMode.restricted:
      return isAllowedForRestricted(path) ? null : RouteNames.restrictedAccount;
    case AccountMode.linkedDevice:
      // Lista blanca del teléfono vinculado (los términos pendientes los
      // resuelve el router antes de llegar aquí).
      return deviceRouteRedirect(
        path: path,
        legalPending: false,
        needsRegistration: needsPostRegistration,
      );
    case AccountMode.teenPending:
      if (isAllowedForPendingTeen(path)) return null;
      return needsPostRegistration
          ? RouteNames.postRegistration
          : RouteNames.teenPendingHome;
    case AccountMode.teenSupervised:
      if (isTeenOnlyRoute(path) ||
          isRestrictedOnlyRoute(path) ||
          isDeviceOnlyRoute(path) ||
          isBlockedForActiveTeen(path)) {
        return RouteNames.homeDashboard;
      }
      return null;
  }
}
