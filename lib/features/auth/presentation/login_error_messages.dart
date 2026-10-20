import 'package:easy_localization/easy_localization.dart';

import '../../../core/errors/failures.dart';
import '../../../core/errors/user_error_message.dart';

/// Códigos de negocio del login (FP3-08, FP3-10, FP3-13, FP3-16).
const String kAuthLoginLockedCode = 'AUTH_LOGIN_LOCKED';
const String kAuthSupervisedLoginDisabledCode =
    'AUTH_SUPERVISED_LOGIN_DISABLED';
const String kAuthAccountFrozenCode = 'AUTH_ACCOUNT_FROZEN';
const String kAuthSupervisedAccessRevokedCode =
    'AUTH_SUPERVISED_ACCESS_REVOKED';

/// Mensaje traducido para un fallo de `POST /auth/login`.
///
/// Solo mira el `code` de negocio (y el `Retry-After` del bloqueo); nunca el
/// texto crudo del servidor ni `details`:
/// - 429 `AUTH_LOGIN_LOCKED`: "inténtalo más tarde", con los minutos si el
///   servidor los indicó.
/// - 403 `AUTH_SUPERVISED_LOGIN_DISABLED` y `AUTH_ACCOUNT_FROZEN`: mensajes
///   propios. El servidor solo los revela tras una contraseña correcta.
/// - 401 (con o sin código): credenciales incorrectas, uniforme.
/// - Sin red: mensaje de conexión. Cualquier otra cosa: error genérico.
String loginErrorMessage(Failure failure) {
  final code = failure.errorCode;
  if (code == kAuthLoginLockedCode) {
    final seconds = failure is AuthFailure ? failure.retryAfterSeconds : null;
    if (seconds != null && seconds > 0) {
      final minutes = (seconds / 60).ceil();
      return 'errors.auth_login_locked_wait'
          .tr(namedArgs: {'minutes': '$minutes'});
    }
    return 'errors.auth_login_locked'.tr();
  }
  if (code == null && failure.code == 401) {
    return 'errors.auth_invalid_credentials'.tr();
  }
  return userErrorMessage(failure, fallbackKey: 'auth.errors.sign_in_failed');
}
