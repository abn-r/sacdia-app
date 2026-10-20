import 'route_names.dart';

/// Rutas de `go_router` que el teléfono vinculado de un menor puede abrir
/// (FP3-52). LISTA BLANCA estricta: todo lo demás vuelve al inicio del
/// dispositivo, también los enlaces profundos y los push.
///
/// Permitido: inicio, clases (lista, detalle y subida de evidencia), agenda
/// (lista y detalle), bandeja de avisos, el bloqueo por términos pendientes y la
/// pantalla de registro incompleto. NO existen en esta cáscara: login, perfil,
/// ajustes de seguridad o sesiones, Mi familia, selector de perfiles,
/// especialidades, miembros, unidades, credencial de otros, exportación ni
/// borrado de cuenta.
///
/// El servidor es la autoridad (alcances `self:read`, `evidence:*`,
/// `push:register`, `agenda:read`); esto solo evita pantallas que acabarían en
/// 403.
const Set<String> _deviceAllowedExact = {
  RouteNames.deviceHome,
  RouteNames.deviceClasses,
  RouteNames.deviceAgenda,
  RouteNames.deviceInbox,
  RouteNames.notificationsInbox,
};

/// Prefijos de detalle: `/device/classes/:id[/requirements/:id]` y
/// `/device/agenda/:id`.
const List<String> _deviceAllowedPrefixes = [
  '${RouteNames.deviceClasses}/',
  '${RouteNames.deviceAgenda}/',
];

String _normalize(String path) => path.length > 1 && path.endsWith('/')
    ? path.substring(0, path.length - 1)
    : path;

/// ¿Puede el teléfono vinculado abrir [path] (con sesión ya cargada y sin
/// pendientes)?
bool isAllowedForDevice(String path) {
  final normalized = _normalize(path);
  if (_deviceAllowedExact.contains(normalized)) return true;
  return _deviceAllowedPrefixes.any(normalized.startsWith);
}

/// Destino de inicio del dispositivo según lo que le falte.
///
/// - Términos pendientes: el teléfono no puede aceptarlos (no tiene
///   `legal:accept`); su tutor lo hace actuando por el menor.
/// - Registro incompleto: el teléfono NUNCA entra al post-registro; muestra una
///   pantalla que pide al tutor terminarlo.
String deviceHomeFor({
  required bool legalPending,
  required bool needsRegistration,
}) {
  if (legalPending) return RouteNames.deviceLegalBlock;
  if (needsRegistration) return RouteNames.deviceRegistrationPending;
  return RouteNames.deviceHome;
}

/// A dónde llevar al teléfono vinculado desde [path], o `null` si puede seguir.
///
/// Orden: términos pendientes > registro incompleto > lista blanca. Las
/// pantallas de bloqueo no son destino de nadie más: sin su causa vuelven al
/// inicio.
String? deviceRouteRedirect({
  required String path,
  required bool legalPending,
  required bool needsRegistration,
}) {
  final normalized = _normalize(path);
  if (legalPending) {
    return normalized == RouteNames.deviceLegalBlock
        ? null
        : RouteNames.deviceLegalBlock;
  }
  if (needsRegistration) {
    return normalized == RouteNames.deviceRegistrationPending
        ? null
        : RouteNames.deviceRegistrationPending;
  }
  if (normalized == RouteNames.deviceLegalBlock ||
      normalized == RouteNames.deviceRegistrationPending) {
    return RouteNames.deviceHome;
  }
  return isAllowedForDevice(normalized) ? null : RouteNames.deviceHome;
}
