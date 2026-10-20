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
///   servidor los indicó (encabezado `Retry-After`).
/// - 429 sin `code` (limitador genérico): "espera un momento", con los mismos
///   minutos si hay `Retry-After`.
/// - 403 `AUTH_SUPERVISED_LOGIN_DISABLED` y `AUTH_ACCOUNT_FROZEN`: mensajes
///   propios. El servidor solo los revela tras una contraseña correcta.
/// - 401 (con o sin código): credenciales incorrectas, uniforme.
/// - Sin red: mensaje de conexión. Cualquier otra cosa: error genérico.
String loginErrorMessage(Failure failure) {
  final code = failure.errorCode;
  // Cualquier 429 de `POST /auth/login`: el bloqueo de negocio
  // (`AUTH_LOGIN_LOCKED`) o el limitador genérico (`ThrottlerException`, sin
  // `code`). Ambos usan `Retry-After` si el servidor lo envió.
  if (code == kAuthLoginLockedCode || failure.code == 429) {
    final seconds = failure is AuthFailure ? failure.retryAfterSeconds : null;
    if (seconds != null && seconds > 0) {
      final minutes = (seconds / 60).ceil();
      return 'errors.auth_login_locked_wait'
          .tr(namedArgs: {'minutes': '$minutes'});
    }
    return code == kAuthLoginLockedCode
        ? 'errors.auth_login_locked'.tr()
        : 'errors.auth_login_throttled'.tr();
  }
  if (code == null && failure.code == 401) {
    return 'errors.auth_invalid_credentials'.tr();
  }
  return userErrorMessage(failure, fallbackKey: 'auth.errors.sign_in_failed');
}
