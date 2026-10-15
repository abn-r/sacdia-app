import 'route_names.dart';

/// Rutas que puede abrir un pastor sin club (ver `isPastorWithoutClub`).
///
/// Solo «Autorizaciones» (listado y detalle) y su perfil. El inicio del pastor
/// es `/home/dashboard`, que dibuja el listado de autorizaciones, y la
/// información médica es un dato propio del perfil. Editar el perfil, los
/// ajustes y cerrar sesión se abren con `Navigator.push` desde el perfil, así
/// que no pasan por el router. Honores, certificaciones, importación de
/// certificados, clases, clubes y demás quedan fuera.
const Set<String> _pastorExactPaths = {
  RouteNames.homeDashboard,
  RouteNames.homeProfile,
  RouteNames.homeMedicalInfo,
  RouteNames.investitureAuthorize,
};

final RegExp _authorizeDetailPath = RegExp(r'^/investiture/authorize/[^/]+$');

/// ¿Puede el pastor sin club abrir [path]? (ruta ya resuelta, sin query).
bool isPastorAllowedPath(String path) {
  final normalized = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  return _pastorExactPaths.contains(normalized) ||
      _authorizeDetailPath.hasMatch(normalized);
}
