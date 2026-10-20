import 'package:easy_localization/easy_localization.dart';

import '../../../core/consent/consent_error_messages.dart';
import '../../../core/errors/failures.dart';

/// Códigos de negocio del backend → llave de traducción `errors.*`.
///
/// Solo se usa el `code` (nunca `details`: el backend lo omite en producción).
/// La llave es el código en minúsculas, igual que el resto de `errors.*`.
const Set<String> familyErrorCodes = {
  'GUARDIANSHIP_NOT_FOUND',
  'GUARDIANSHIP_DEPENDENT_AGE_OUT_OF_RANGE',
  'GUARDIANSHIP_GUARDIAN_NOT_ADULT',
  'GUARDIANSHIP_GUARDIAN_BIRTHDAY_REQUIRED',
  'GUARDIANSHIP_DEPENDENT_LIMIT_REACHED',
  'GUARDIANSHIP_GUARDIAN_LIMIT_REACHED',
  'GUARDIANSHIP_LINK_CODE_INVALID',
  'GUARDIANSHIP_LINK_CODE_LOCKED',
  'GUARDIANSHIP_LINK_CODE_SELF_REDEEM',
  'GUARDIANSHIP_ALREADY_GUARDIAN',
  'GUARDIANSHIP_REVOKE_FORBIDDEN',
  'GUARDIANSHIP_RELATIONSHIP_TYPE_INVALID',
  'GUARDIANSHIP_RELATIONSHIP_TYPE_NOT_ALLOWED',
  'ACTING_FOR_HEADER_INVALID',
  'ACTING_FOR_FORBIDDEN',
  'ACTING_FOR_SCOPE_DENIED',
  'AUTH_DELETE_DEPENDENTS_ACK_REQUIRED',
  'AUTH_REGISTRATION_AGE_BELOW_MINIMUM',
  'USER_SELF_ACCOUNT_BELOW_MINIMUM_AGE',
  'POST_REG_GUARDIAN_ONLY_REQUIRES_ADULT',
  'MR_CONSENT_NOT_VERIFIED',
  'LEGAL_VERSION_MISMATCH',
  // Fase 3a: acceso propio del menor y resumen del tutor.
  'SUPERVISED_LOGIN_NOT_ELIGIBLE',
  'SUPERVISED_LOGIN_AGE_OUT_OF_RANGE',
  'SUPERVISED_LOGIN_ALREADY_ENABLED',
  'SUPERVISED_LOGIN_NOT_FOUND',
  'SUPERVISED_LOGIN_EMAIL_UNAVAILABLE',
  'SUPERVISED_LOGIN_PASSWORD_INVALID',
  'GUARDIANSHIP_CONSENT_NOT_VERIFIED',
  'FAMILY_FEATURE_DISABLED',
  'PRINCIPAL_SCOPE_DENIED',
  // Fase 3b: teléfonos vinculados de un menor. El motivo exacto de
  // DEVICE_PAIRING_NOT_ELIGIBLE viaja en `details`, que no se lee jamás.
  'DEVICE_PAIRING_NOT_ELIGIBLE',
  'DEVICE_LIMIT_REACHED',
  'LINKED_DEVICE_LIMIT_REACHED',
  'LINKED_DEVICE_AGE_OUT_OF_RANGE',
  'DEVICE_NOT_FOUND',
  'LINKED_DEVICE_NOT_FOUND',
};

/// Llave `errors.*` de un código, o `null` si no es uno de Mi familia.
String? familyErrorKey(String? code) {
  if (code == null) return null;
  if (!familyErrorCodes.contains(code)) return consentErrorKey(code);
  return 'errors.${code.toLowerCase()}';
}

/// Mensaje traducido para un fallo de Mi familia.
///
/// - Código conocido → su mensaje.
/// - Sin red → mensaje de conexión.
/// - Cualquier otra cosa → mensaje genérico (nunca el texto crudo del servidor).
String familyErrorMessage(Object? error) {
  if (error is Failure) {
    final key = familyErrorKey(error.errorCode);
    if (key != null) return key.tr();
    if (error is NetworkFailure || error is ConnectionFailure) {
      return 'errors.connection_error'.tr();
    }
    // Un 429 del limitador (p. ej. 10 códigos de vinculación por hora) llega
    // SIN código de negocio: mensaje de «demasiados intentos».
    if (error.code == 429) return 'errors.too_many_attempts'.tr();
  }
  return 'family.errors.generic'.tr();
}

/// El tutor es menor o no tiene fecha de nacimiento: la solución es completar
/// su propio perfil.
bool isGuardianProfileIncomplete(Object? error) {
  if (error is! Failure) return false;
  return error.errorCode == 'GUARDIANSHIP_GUARDIAN_NOT_ADULT' ||
      error.errorCode == 'GUARDIANSHIP_GUARDIAN_BIRTHDAY_REQUIRED';
}
