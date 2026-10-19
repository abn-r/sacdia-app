import 'package:easy_localization/easy_localization.dart';

import '../errors/failures.dart';

/// Códigos de negocio de la ficha de consentimiento (Phase 2c) -> llave
/// `errors.*` (el código en minúsculas).
///
/// Solo se usa el `code` (nunca `details`: el backend lo omite en producción).
const Set<String> consentErrorCodes = {
  'GUARDIANSHIP_EVIDENCE_NOT_FOUND',
  'GUARDIANSHIP_EVIDENCE_REQUIRED',
  'GUARDIANSHIP_EVIDENCE_UNAVAILABLE',
  'GUARDIANSHIP_CUSTODIAN_SELF_VERIFY',
  // 403 al verificar: quien verifica es tutor del menor (cuatro ojos, W2).
  'GUARDIANSHIP_GUARDIAN_SELF_VERIFY',
  // 409 al subir una ficha cuando el consentimiento ya quedó verificado (W1).
  'GUARDIANSHIP_CONSENT_ALREADY_VERIFIED',
  'MR_CONSENT_CONFIRMATION_REQUIRED',
  'MR_CONSENT_NOT_VERIFIED',
  'MR_NOT_FOUND',
  'MR_ALREADY_PENDING',
  'GUARDIANSHIP_NOT_FOUND',
  'GUARD_PERMISSION_DENIED',
  'FILE_REQUIRED',
  'FILE_TYPE_INVALID',
  'FILE_TOO_LARGE',
  // Un tutor que sube la ficha con `X-Acting-For` (no debería: la app lo omite)
  // o que perdió el acceso: se informa sin salir del perfil actual.
  'ACTING_FOR_SCOPE_DENIED',
  'ACTING_FOR_FORBIDDEN',
};

/// Llave `errors.*` de un código de consentimiento, o `null`.
String? consentErrorKey(String? code) {
  if (code == null || !consentErrorCodes.contains(code)) return null;
  return 'errors.${code.toLowerCase()}';
}

/// El almacén privado de fichas no está configurado (503 fail closed): se
/// muestra "aún no disponible" y no se ofrece reintentar subir.
bool isConsentEvidenceUnavailable(Object? error) =>
    error is Failure && error.errorCode == 'GUARDIANSHIP_EVIDENCE_UNAVAILABLE';

/// Todavía no hay ficha subida (404 al pedir la ficha vigente).
bool isConsentEvidenceNotFound(Object? error) =>
    error is Failure && error.errorCode == 'GUARDIANSHIP_EVIDENCE_NOT_FOUND';

/// Verificar con el mismo usuario que subió la ficha o recibió la custodia
/// (cuatro ojos, 403).
bool isCustodianSelfVerify(Object? error) =>
    error is Failure && error.errorCode == 'GUARDIANSHIP_CUSTODIAN_SELF_VERIFY';

/// Se intentó subir una ficha cuando el consentimiento ya está verificado (409).
/// Reemplazarla solo se puede tras revocar la tutoría.
bool isConsentAlreadyVerified(Object? error) =>
    error is Failure &&
    error.errorCode == 'GUARDIANSHIP_CONSENT_ALREADY_VERIFIED';

/// Mensaje traducido de un fallo de la ficha de consentimiento.
///
/// - Código conocido -> su mensaje.
/// - 413 (límite de multer, sin código) -> "archivo demasiado grande".
/// - 429 -> "demasiados intentos".
/// - Sin red -> mensaje de conexión.
/// - Cualquier otra cosa -> mensaje genérico (nunca el texto crudo del servidor).
String consentErrorMessage(Object? error) {
  if (error is Failure) {
    final key = consentErrorKey(error.errorCode);
    if (key != null) return key.tr();
    if (error is NetworkFailure || error is ConnectionFailure) {
      return 'errors.connection_error'.tr();
    }
    if (error.code == 413) return 'errors.file_too_large'.tr();
    if (error.code == 429) return 'core.consent.errors.rate_limited'.tr();
  }
  return 'core.consent.errors.generic'.tr();
}
