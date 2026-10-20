import 'package:sentry_flutter/sentry_flutter.dart';

/// Texto con el que se sustituye un secreto de vinculación.
const String kRedacted = '[REDACTED]';

/// `sacdia://pair?c=<token>` (o `?t=`): conserva el enlace, borra la consulta.
final RegExp _pairLink = RegExp(
  r'sacdia:(?://|///)pair\b[^\s"\x27<>)\]]*',
  caseSensitive: false,
);

/// Claves que llevan el token de vinculación.
const Set<String> _secretKeys = {
  'pairing_token',
  'pairingToken',
};

/// Reemplaza cualquier enlace de vinculación en [text] por `sacdia://pair?
/// [REDACTED]`. El token jamás debe llegar a un log, a Sentry ni a un
/// breadcrumb (FP3-51).
String redactPairingLinks(String text) {
  return text.replaceAllMapped(_pairLink, (_) => 'sacdia://pair?$kRedacted');
}

dynamic _redactValue(dynamic value) {
  if (value is String) return redactPairingLinks(value);
  if (value is Map) {
    for (final key in value.keys.toList()) {
      if (key is String && _secretKeys.contains(key)) {
        value[key] = kRedacted;
      } else {
        value[key] = _redactValue(value[key]);
      }
    }
    return value;
  }
  if (value is List) {
    for (var i = 0; i < value.length; i++) {
      value[i] = _redactValue(value[i]);
    }
    return value;
  }
  return value;
}

/// Limpia un breadcrumb de Sentry: mensaje y datos sin el token de vinculación.
/// Pensado para `SentryOptions.beforeBreadcrumb` y para el filtro de eventos.
Breadcrumb? redactPairingBreadcrumb(Breadcrumb? crumb) {
  if (crumb == null) return null;
  final message = crumb.message;
  if (message != null) crumb.message = redactPairingLinks(message);
  final data = crumb.data;
  if (data != null) _redactValue(data);
  return crumb;
}
