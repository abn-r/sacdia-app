import '../config/route_names.dart';
import '../../features/auth/domain/entities/user_entity.dart';

/// `data.type` del push mensual (día 25) que recuerda registrar los
/// movimientos del mes. Trae `club_section_id`, `year` y `month`, pero NO una
/// ruta: el destino lo decide la app.
const String financesReminderPushType = 'finances_reminder';

/// `source` de la misma notificación en la bandeja.
const String financesReminderSource = 'finances:reminder';

/// ¿El push es el recordatorio de finanzas?
bool isFinancesReminderPushType(String? type) =>
    type?.trim() == financesReminderPushType;

/// ¿La notificación de la bandeja es el recordatorio de finanzas?
bool isFinancesReminderSource(String? source) =>
    source?.trim().toLowerCase() == financesReminderSource;

/// Destino del recordatorio: Finanzas de la sección activa del usuario.
///
/// Las finanzas son asunto del personal del club: sin sesión, con cuenta
/// limitada (adolescente, restringida o sin edad) o mientras se actúa por un
/// menor no hay destino (el aviso solo informa). Un teléfono vinculado nunca
/// llega aquí: lo resuelve `deviceRouteForPush`.
String? financesReminderRouteFor(UserEntity? user, {required bool acting}) {
  if (user == null || acting || user.isLimitedAccount) return null;
  return RouteNames.homeFinances;
}
