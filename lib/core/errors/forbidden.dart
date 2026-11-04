import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../widgets/sac_error_state.dart';
import 'authorization_stale.dart';
import 'exceptions.dart';
import 'failures.dart';

/// Un error que ya sabe si es un «acceso restringido»: lo implementan las
/// excepciones de carga de las features que envuelven un [Failure] (p. ej.
/// `CoordinatorLoadException`) para que [isForbiddenFailure] las reconozca sin
/// que `core` dependa de ellas.
abstract interface class ForbiddenAware {
  bool get isForbidden;
}

/// Códigos de negocio que significan «no tienes permiso», sin importar el
/// estado HTTP.
const Set<String> _forbiddenCodes = {
  'GUARD_PERMISSION_DENIED',
  'GUARD_CLUB_SCOPE_REQUIRED',
};

/// Prefijos de códigos que NO son un acceso restringido de la pantalla aunque
/// lleguen con 403: pertenecen al modo «actuar por» y al principal
/// (adolescente, teléfono vinculado), que tienen sus propios interceptores y
/// nunca se tocan desde aquí.
const List<String> _excludedCodePrefixes = ['ACTING_FOR_', 'PRINCIPAL_SCOPE_'];

/// ¿[error] significa que el usuario no tiene permiso (HTTP 403 o un código de
/// negocio `GUARD_PERMISSION_DENIED`, `GUARD_CLUB_SCOPE_REQUIRED` o
/// `*_FORBIDDEN`)?
///
/// Es el ÚNICO criterio de la app para mostrar [ForbiddenView] /
/// `SacErrorState.forbidden`. Excluye `ACTING_FOR_*` y `PRINCIPAL_SCOPE_*`
/// (los resuelven sus interceptores) y el rechazo local `AUTHORIZATION_STALE`.
/// Solo se lee el `code`; nunca `details`.
bool isForbiddenFailure(Object error) {
  if (error is ForbiddenAware) return error.isForbidden;

  final int? status;
  final String? rawCode;
  switch (error) {
    case AppException(:final code, :final errorCode):
      status = code;
      rawCode = errorCode;
    case Failure(:final code, :final errorCode):
      status = code;
      rawCode = errorCode;
    case DioException(:final response, :final error):
      status = response?.statusCode;
      final data = response?.data;
      rawCode = data is Map
          ? data['code']?.toString()
          : (error is AppException ? error.errorCode : null);
    default:
      return false;
  }

  final code = rawCode?.trim().toUpperCase();
  if (code != null && code.isNotEmpty) {
    if (_excludedCodePrefixes.any(code.startsWith)) return false;
    // Rechazo local por autorización obsoleta (sesión restaurada sin red): es
    // un error de ESA mutación, no un acceso restringido de la pantalla.
    if (code == kAuthorizationStaleCode) return false;
    if (_forbiddenCodes.contains(code) || code.endsWith('_FORBIDDEN')) {
      return true;
    }
  }
  return status == 403;
}

/// Estado único de «acceso restringido» de la app: `SacErrorState.forbidden`
/// con su copia estándar. Las vistas lo muestran cuando [isForbiddenFailure]
/// acepta el error de carga; el router manda a `AccessDeniedView` (que lo usa)
/// cuando el catálogo niega la ruta.
class ForbiddenView extends StatelessWidget {
  const ForbiddenView({
    super.key,
    this.padding = const EdgeInsets.all(32),
    this.scrollable = false,
  });

  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return SacErrorState.forbidden(padding: padding, scrollable: scrollable);
  }
}
