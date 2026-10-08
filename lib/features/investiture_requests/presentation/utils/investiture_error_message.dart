import 'package:easy_localization/easy_localization.dart';

import '../../../../core/errors/failures.dart';

/// Texto para mostrar al usuario de un error de lectura.
///
/// Los `Failure` ya traen el mensaje mapeado desde el código del backend; su
/// `toString()` no sirve (Equatable no lo imprime en release). Cualquier otro
/// error se reemplaza por el texto genérico traducido, sin filtrar detalles.
String investitureErrorMessage(Object? error) {
  if (error is Failure && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return tr('investiture_requests.errors.generic');
}
