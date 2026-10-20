import '../config/route_names.dart';

/// Destino de un push tocado en el teléfono vinculado de un menor (FP3-52).
///
/// En ese modo se IGNORA `dependent_user_id` (no hay perfiles que confirmar) y
/// solo se abren pantallas de la cáscara del dispositivo:
/// - `/class/<id>` → el detalle de esa clase del dispositivo;
/// - `/activity/<id>` → el detalle de esa actividad;
/// - cualquier otro destino (rutas de cuentas, tipos con lógica propia, datos
///   inesperados) → la bandeja de avisos, que es lo que el menor puede ver.
String deviceRouteForPush(Map<String, dynamic> data) {
  final route = data['route'];
  if (route is String) {
    final klass = RegExp(r'^/class/(\d+)$').firstMatch(route);
    if (klass != null) {
      return RouteNames.deviceClassDetailPath(int.parse(klass.group(1)!));
    }
    final activity = RegExp(r'^/activity/(\d+)$').firstMatch(route);
    if (activity != null) {
      return RouteNames.deviceActivityDetailPath(int.parse(activity.group(1)!));
    }
  }
  return RouteNames.deviceInbox;
}
