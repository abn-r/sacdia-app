/// Enmascara la parte identificatoria de una dirección IP para proteger la
/// privacidad del usuario al mostrarla en vistas públicas/de auditoría.
///
/// IPv4: reemplaza el último octeto por `xxx` → `192.168.1.xxx`
/// IPv6: reemplaza el último grupo por `xxxx` → `2001:db8::1:2:3:xxxx`
/// Null / vacío / no reconocido: devuelve `'IP desconocida'`.
String maskIpAddress(String? ip) {
  if (ip == null || ip.isEmpty) return 'IP desconocida';

  // IPv4: cuatro grupos de dígitos separados por puntos.
  final ipv4 = RegExp(r'^(\d{1,3}\.\d{1,3}\.\d{1,3})\.\d{1,3}$');
  final v4Match = ipv4.firstMatch(ip);
  if (v4Match != null) return '${v4Match.group(1)}.xxx';

  // IPv6: al menos un colon presente.
  if (ip.contains(':')) {
    final lastColon = ip.lastIndexOf(':');
    return '${ip.substring(0, lastColon)}:xxxx';
  }

  return 'IP desconocida';
}
