import 'package:easy_localization/easy_localization.dart';

import '../../../core/errors/failures.dart';
import '../../family/presentation/family_error_messages.dart';

/// Códigos de la Fase 4 del backend → llave `errors.<código en minúsculas>`.
///
/// Solo se lee `code` (jamás `details`). El texto crudo del servidor no se
/// muestra nunca.
const Set<String> majorityReleaseErrorCodes = {
  'FAMILY_RELEASE_NOT_PENDING',
  'FAMILY_RELEASE_EMAIL_UNAVAILABLE',
  'FAMILY_RELEASE_EMAIL_ALREADY_SET',
  'FAMILY_ADULT_CLAIM_EMAIL_UNAVAILABLE',
  'FAMILY_ADULT_CLAIM_NOT_RELEASED',
};

/// El estado local quedó viejo (ya tiene correo o ya no está pendiente): hay
/// que releer `/auth/me` en lugar de pedir otra cosa al usuario.
bool isStaleReleaseState(Object? error) =>
    error is Failure &&
    (error.errorCode == 'FAMILY_RELEASE_NOT_PENDING' ||
        error.errorCode == 'FAMILY_RELEASE_EMAIL_ALREADY_SET');

/// Mensaje traducido de un fallo de la liberación.
///
/// - Código de la Fase 4 → su mensaje.
/// - Cualquier otro código de familia (`GUARDIANSHIP_LINK_CODE_*`...) → el de
///   Mi familia.
/// - Sin red o 429 → los genéricos de [familyErrorMessage].
String majorityReleaseErrorMessage(Object? error) {
  if (error is Failure) {
    final code = error.errorCode;
    if (code != null && majorityReleaseErrorCodes.contains(code)) {
      return 'errors.${code.toLowerCase()}'.tr();
    }
  }
  return familyErrorMessage(error);
}
