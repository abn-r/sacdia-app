import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import '../utils/app_logger.dart';

/// Qué cáscara de la app abre esta instalación (FP3-52).
///
/// - [account]: una persona con cuenta (adulto, tutor, adolescente).
/// - [device]: el teléfono de un menor de 13 vinculado por su tutor. Su sesión
///   es del tipo `linked_device`.
///
/// El modo NO es identidad ni permiso: el servidor decide qué puede hacer cada
/// sesión (`/auth/me.principal.kind` es la autoridad). Esta bandera solo existe
/// para elegir la cáscara en el arranque en frío, antes de que `/auth/me`
/// responda, y para no inicializar la analítica en un teléfono de menor. Por eso
/// vive ÚNICAMENTE en el almacenamiento seguro, junto a los tokens de la sesión,
/// y se reescribe en cuanto el servidor dice otra cosa.
enum SessionMode {
  account,
  device;

  /// Valor guardado. Cualquier otra cosa (ausente, corrupta) es [account]: un
  /// error de lectura nunca convierte una sesión de cuenta en una de
  /// dispositivo; la sesión de dispositivo se re-confirma con `/auth/me`.
  static SessionMode parse(String? raw) =>
      raw == 'device' ? SessionMode.device : SessionMode.account;

  String get wire => name;
}

/// Lee, escribe y borra la bandera `session_mode` en el almacenamiento seguro.
class SessionModeStore {
  SessionModeStore(this._storage);

  final SecureStorage _storage;

  static const _tag = 'SessionMode';

  Future<SessionMode> read() async {
    try {
      return SessionMode.parse(
        await _storage.read(AppConstants.sessionModeKey),
      );
    } catch (e) {
      AppLogger.w('No se pudo leer el modo de sesión', tag: _tag, error: e);
      return SessionMode.account;
    }
  }

  /// Solo escribe `device`; el modo cuenta es la AUSENCIA de la bandera.
  Future<void> write(SessionMode mode) async {
    try {
      if (mode == SessionMode.device) {
        await _storage.write(AppConstants.sessionModeKey, mode.wire);
      } else {
        await _storage.delete(AppConstants.sessionModeKey);
      }
    } catch (e) {
      AppLogger.w('No se pudo guardar el modo de sesión', tag: _tag, error: e);
    }
  }

  Future<void> clear() => write(SessionMode.account);
}

/// Lectura puntual del modo guardado, para `main()` antes de que exista un
/// `ProviderContainer` (decide si se inicializa la analítica).
Future<SessionMode> readPersistedSessionMode() =>
    SessionModeStore(SecureStorageImpl()).read();

/// Modo de la sesión vigente, en memoria.
///
/// Lo escribe `AuthNotifier` (arranque en frío, emparejado, `/auth/me`,
/// cierre de sesión) y lo lee el cliente HTTP para no mandar nunca
/// `X-Acting-For` desde un teléfono vinculado. Es plomería de la sesión: se
/// reinicia al cerrar sesión y no guarda datos del usuario.
final sessionModeProvider =
    StateProvider<SessionMode>((ref) => SessionMode.account);
