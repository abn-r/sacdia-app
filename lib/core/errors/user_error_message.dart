import 'package:easy_localization/easy_localization.dart';

import 'exceptions.dart';
import 'failures.dart';

/// Mensaje traducido y apto para el usuario a partir de cualquier error.
///
/// Nunca devuelve `toString()` ni el texto crudo del servidor (p. ej.
/// `AppException: ... (Code: null)`). Orden:
/// 1. Código de negocio con traducción `errors.<codigo_en_minusculas>`
///    (`ACTING_FOR_SCOPE_DENIED`, `GUARDIANSHIP_*`, ...).
/// 2. Sin red / timeout → mensaje de conexión.
/// 3. Cualquier otra cosa → [fallbackKey] (por defecto `common.error_generic`).
///
/// Solo se lee el `code` de negocio; `details` NUNCA (ruling #11528).
String userErrorMessage(
  Object? error, {
  String fallbackKey = 'common.error_generic',
}) {
  final code = switch (error) {
    AppException(:final errorCode) => errorCode,
    Failure(:final errorCode) => errorCode,
    _ => null,
  };
  if (code != null && code.isNotEmpty) {
    final key = 'errors.${code.toLowerCase()}';
    final message = key.tr();
    if (message != key) return message;
  }
  if (error is ConnectionException ||
      error is ConnectionFailure ||
      error is NetworkFailure) {
    return 'errors.connection_error'.tr();
  }
  return fallbackKey.tr();
}
