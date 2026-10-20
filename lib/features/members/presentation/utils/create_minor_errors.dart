import 'package:easy_localization/easy_localization.dart';

import '../../../../core/errors/failures.dart';
import '../../../family/presentation/family_error_messages.dart';

/// Mensaje de un fallo al registrar a un menor como director.
///
/// Solo mira el `code` (nunca `details`). Dos códigos cambian de redacción
/// respecto de Mi familia: el rango de edad aquí es "menor de edad según el país
/// del club" (no "menor de 13") y el año eclesiástico vigente es propio de este
/// flujo. El resto reutiliza el mapa de Mi familia (versión legal vencida,
/// bandera apagada, demasiados intentos, sin permiso, genérico).
String createMinorErrorMessage(Object? error) {
  if (error is Failure) {
    switch (error.errorCode) {
      case 'GUARDIANSHIP_DEPENDENT_AGE_OUT_OF_RANGE':
        return 'members.create_minor.errors.age_out_of_range'.tr();
      case 'POST_REG_NO_ACTIVE_YEAR':
        return 'members.create_minor.errors.no_active_year'.tr();
    }
  }
  return familyErrorMessage(error);
}
