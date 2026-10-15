import '../../../core/config/route_names.dart';

/// Acción de navegación que ofrece el detalle de una notificación.
class NotificationAction {
  /// Clave de traducción del texto del botón.
  final String labelKey;

  /// Ruta de destino (debe existir en el router).
  final String route;

  const NotificationAction({required this.labelKey, required this.route});
}

/// Resuelve la acción de una notificación del historial a partir de su
/// `source`.
///
/// El historial (`notification_logs`) no guarda el payload de datos del push
/// (`route`, mes, año), así que la acción se deduce del origen.
NotificationAction? notificationActionFor(String? source) {
  final normalized = source?.trim().toLowerCase() ?? '';

  // Recordatorios del informe mensual (`monthly_reports:reminder`): todos se
  // resuelven en la pantalla Reportes, igual que el `route` del push.
  if (normalized.startsWith('monthly_reports:')) {
    return const NotificationAction(
      labelKey: 'notifications.inbox.detail_open_reports',
      route: RouteNames.homeReports,
    );
  }

  return null;
}
