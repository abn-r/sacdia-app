import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Esquema y host del QR de vinculación (`sacdia://pair?t=<token>`, contrato confirmado del backend).
const String kPairLinkScheme = 'sacdia';
const String kPairLinkHost = 'pair';

/// Extrae el token de vinculación de un enlace `sacdia://pair?t=...`, o `null`
/// si [uri] no es un enlace de vinculación válido.
///
/// El backend confirmó `t`; la spec decía `c`: se aceptan los dos. El token NUNCA se registra ni se copia a
/// otro sitio que no sea la memoria de [pairingLinkProvider].
String? pairingTokenFromUri(Uri uri) {
  if (uri.scheme.toLowerCase() != kPairLinkScheme) return null;
  // `sacdia://pair?c=x` llega con host `pair`; algunos lanzadores lo entregan
  // como `sacdia:///pair?c=x` (ruta `/pair`).
  final isPair = uri.host.toLowerCase() == kPairLinkHost ||
      uri.path.toLowerCase() == '/$kPairLinkHost';
  if (!isPair) return null;
  final raw = uri.queryParameters['c'] ?? uri.queryParameters['t'];
  return normalizePairingToken(raw);
}

/// Token válido (base64url, sin espacios) o `null`. No valida la longitud: el
/// servidor es quien decide; solo descarta basura evidente antes de gastar una
/// llamada.
String? normalizePairingToken(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty || value.length > 256) return null;
  if (!RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(value)) return null;
  return value;
}

/// Token de un enlace de vinculación recibido mientras la app arrancaba o
/// había una sesión. Solo en memoria. Lo consume `PairDeviceView` (que lo borra
/// al leerlo) y lo descarta el cierre de sesión. No es estado de perfil.
final pairingLinkProvider = StateProvider<String?>((ref) => null);
