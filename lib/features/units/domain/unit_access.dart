import '../../auth/domain/entities/user_entity.dart';
import '../../auth/domain/utils/authorization_utils.dart';
import 'entities/unit.dart';

/// ¿Puede [user] capturar y guardar la planilla semanal de puntos de [unit]?
///
/// - Quien tiene `units:update` y `units:create` (directiva) la captura en
///   cualquier unidad.
/// - Quien dirige la unidad (capitán, secretario, consejero o suplente) la
///   captura en SU unidad aunque su rol de club sea solo miembro y no tenga
///   `units:update`.
/// - Cualquier otro (por ejemplo `units:read` sin dirigir la unidad) solo
///   lee.
bool canRegisterUnitPoints(UserEntity? user, Unit unit) {
  if (user == null) return false;
  if (hasAnyPermission(user, const {'units:update'}) &&
      hasAnyPermission(user, const {'units:create'})) {
    return true;
  }
  return unit.isLedBy(user.id);
}
