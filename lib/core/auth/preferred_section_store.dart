import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/entities/authorization_snapshot.dart';
import '../../features/auth/domain/utils/authorization_utils.dart';
import '../utils/app_logger.dart';

/// Última sección que el usuario eligió en ESTE dispositivo.
///
/// Un director puede liderar dos secciones, así que la app nunca vuelve a una
/// por defecto: tras reiniciar o volver a iniciar sesión se reaplica la última
/// elegida (`AuthNotifier` la reafirma en el servidor con
/// `PATCH /auth/me/context`).
///
/// La clave lleva el `user_id`: dos cuentas en el mismo teléfono no se pisan ni
/// se filtran, y el logout no la borra (la siguiente sesión de la MISMA cuenta
/// la recupera). Solo guarda un `assignment_id` (un UUID sin PII). Nunca se
/// lee ni se escribe mientras se actúa por un dependiente: la elección es del
/// tutor, no del menor.
class PreferredSectionStore {
  PreferredSectionStore(this._prefs);

  final SharedPreferences _prefs;

  static const _tag = 'PreferredSection';
  static const keyPrefix = 'preferred_section.';

  static String keyFor(String userId) => '$keyPrefix$userId';

  /// `assignment_id` guardado para [userId], o `null`.
  String? read(String userId) {
    if (userId.isEmpty) return null;
    try {
      final raw = _prefs.getString(keyFor(userId))?.trim();
      return (raw == null || raw.isEmpty) ? null : raw;
    } catch (e) {
      AppLogger.w('No se pudo leer la sección preferida', tag: _tag, error: e);
      return null;
    }
  }

  Future<void> write(String userId, String assignmentId) async {
    if (userId.isEmpty || assignmentId.isEmpty) return;
    try {
      if (_prefs.getString(keyFor(userId)) == assignmentId) return;
      await _prefs.setString(keyFor(userId), assignmentId);
    } catch (e) {
      AppLogger.w('No se pudo guardar la sección preferida',
          tag: _tag, error: e);
    }
  }

  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    try {
      await _prefs.remove(keyFor(userId));
    } catch (e) {
      AppLogger.w('No se pudo borrar la sección preferida',
          tag: _tag, error: e);
    }
  }
}

/// Qué asignación hay que reafirmar en el servidor, o `null` si no hay que
/// hacer nada.
///
/// Devuelve [stored] solo si difiere de la que el servidor marcó activa Y sigue
/// siendo seleccionable (activa, no programada ni vencida). Si ya no lo es
/// (terminó, se quitó), devuelve `null`: manda la elección del servidor.
String? pickPreferredAssignmentId({
  required AuthorizationSnapshot? authorization,
  required String? stored,
}) {
  if (authorization == null || stored == null || stored.isEmpty) return null;
  if (stored == authorization.activeAssignmentId) return null;
  final selectable = selectableClubAssignments(authorization.clubAssignments);
  final stillValid = selectable.any((grant) => grant.assignmentId == stored);
  return stillValid ? stored : null;
}
