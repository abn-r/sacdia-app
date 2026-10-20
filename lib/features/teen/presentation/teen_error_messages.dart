import 'package:easy_localization/easy_localization.dart';

import '../../../core/errors/failures.dart';
import '../../../core/errors/user_error_message.dart';

/// Mensaje traducido para un fallo de la pantalla del adolescente.
///
/// Solo mira el `code` de negocio (`GUARDIANSHIP_ALREADY_GUARDIAN`,
/// `PRINCIPAL_SCOPE_DENIED`, ...) y el estado 429 del límite de códigos por
/// hora; jamás texto crudo del servidor ni `details`.
String teenErrorMessage(Object? error) {
  if (error is Failure) {
    // En esta pantalla el sujeto es el propio adolescente: los textos
    // genéricos de la tutoría ("ya eres tutor de este menor") no aplican.
    switch (error.errorCode) {
      case 'GUARDIANSHIP_ALREADY_GUARDIAN':
        return 'teen.errors.already_linked'.tr();
      case 'GUARDIANSHIP_NOT_FOUND':
        return 'teen.errors.link_not_found'.tr();
    }
    if (error.code == 429 && error.errorCode == null) {
      return 'teen.errors.too_many_codes'.tr();
    }
  }
  return userErrorMessage(error, fallbackKey: 'teen.errors.generic');
}
