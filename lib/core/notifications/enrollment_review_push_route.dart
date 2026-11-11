import '../config/route_names.dart';
import '../../features/auth/domain/entities/user_entity.dart';

/// `data.type` del push que recibe quien envió la inscripción anual de una
/// sección cuando un revisor la aprueba o la rechaza
/// (`data.action` = `approved` | `rejected`).
const String clubEnrollmentReviewedPushType = 'club_enrollment_reviewed';

/// `source` de la misma notificación en la bandeja.
const String clubEnrollmentReviewedSource = 'club-enrollments:reviewed';

/// ¿El push es el resultado de la revisión de una inscripción anual?
bool isClubEnrollmentReviewedPushType(String? type) =>
    type?.trim() == clubEnrollmentReviewedPushType;

/// ¿La notificación de la bandeja es el resultado de una revisión?
bool isClubEnrollmentReviewedSource(String? source) =>
    source?.trim().toLowerCase() == clubEnrollmentReviewedSource;

/// Destino del aviso: el inicio, donde viven el estado de la inscripción
/// («Inscripción rechazada» con su motivo) y el formulario para corregirla.
///
/// La inscripción es asunto del personal del club: sin sesión, con cuenta
/// limitada (adolescente, restringida o sin edad) o mientras se actúa por un
/// menor no hay destino (el aviso solo informa). Un teléfono vinculado nunca
/// llega aquí: lo resuelve `deviceRouteForPush`.
String? enrollmentReviewedRouteFor(UserEntity? user, {required bool acting}) {
  if (user == null || acting || user.isLimitedAccount) return null;
  return RouteNames.homeDashboard;
}
