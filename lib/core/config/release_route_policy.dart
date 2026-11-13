import '../../features/auth/domain/entities/principal_info.dart';
import 'route_names.dart';

/// Compuerta de rutas de un adulto liberado al cumplir la mayoría de edad
/// (Fase 4, `AccountMode.released`).
///
/// El servidor es la autoridad (`PRINCIPAL_SCOPE_DENIED`); esto solo evita
/// pantallas que acabarían en 403.
///
/// - **Pendiente**: LISTA BLANCA `{/release, /access-denied}`. Los documentos
///   legales se abren en el navegador integrado (no son una ruta), así que no
///   hay nada más que listar.
/// - **Congelado** (nunca se borra solo, R6): LISTA BLANCA
///   `{/release/frozen, /release, /access-denied}`. `/release` está permitida
///   porque aceptar (y agregar el correo si falta) lo descongela (R1).
/// - Quien NO está liberado jamás ve `/release` ni `/release/frozen`: si la
///   persona ya completó, vuelve al inicio de su modo.
///
/// `/adult-claim` es pública y se maneja aparte en el router.

String _normalize(String path) => path.length > 1 && path.endsWith('/')
    ? path.substring(0, path.length - 1)
    : path;

/// ¿Es [path] una de las dos pantallas de la liberación?
bool isReleaseOnlyRoute(String path) {
  final normalized = _normalize(path);
  return normalized == RouteNames.release ||
      normalized == RouteNames.releaseFrozen;
}

/// ¿Puede un adulto liberado PENDIENTE abrir [path]?
bool isAllowedForReleasePending(String path) {
  final normalized = _normalize(path);
  return normalized == RouteNames.release ||
      normalized == RouteNames.accessDenied;
}

/// ¿Puede un adulto liberado CONGELADO abrir [path]?
bool isAllowedForReleaseFrozen(String path) {
  final normalized = _normalize(path);
  return normalized == RouteNames.releaseFrozen ||
      normalized == RouteNames.release ||
      normalized == RouteNames.accessDenied;
}

/// Destino «de inicio» de un adulto liberado.
String releaseHomeFor({required bool frozen}) =>
    frozen ? RouteNames.releaseFrozen : RouteNames.release;

/// A dónde llevar a quien está liberado en [path], o `null` si puede seguir.
String? releaseRouteRedirect({
  required String path,
  required bool frozen,
}) {
  final allowed = frozen
      ? isAllowedForReleaseFrozen(path)
      : isAllowedForReleasePending(path);
  return allowed ? null : releaseHomeFor(frozen: frozen);
}

/// ¿La compuerta de liberación decide algo para [mode]? Solo si está liberado.
bool isReleaseMode(AccountMode mode) => mode == AccountMode.released;
