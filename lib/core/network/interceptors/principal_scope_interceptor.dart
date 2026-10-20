import 'dart:ui' show VoidCallback;

import 'package:dio/dio.dart';

import '../../utils/app_logger.dart';

/// Reacciona al 403 `PRINCIPAL_SCOPE_DENIED` que el servidor da a un
/// adolescente supervisado (o a un teléfono vinculado) en una ruta que su
/// principal no tiene (FP3-19).
///
/// Ese 403 casi siempre significa que el modo de la cuenta cambió en el
/// servidor (el director verificó el consentimiento, el tutor se fue...) y la
/// app sigue con el modo viejo. Avisa por [onScopeDenied] para que la app
/// vuelva a pedir `/auth/me` y el router cambie de pantalla. NO sale de ningún
/// modo "actuar por": esto no es `ACTING_FOR_SCOPE_DENIED` (el del tutor, que se
/// queda como error de esa acción).
///
/// El error sigue su camino intacto: esta acción falló y así se muestra. Solo
/// se lee el `code`, nunca `details`.
class PrincipalScopeInterceptor extends Interceptor {
  PrincipalScopeInterceptor({this.onScopeDenied});

  final VoidCallback? onScopeDenied;

  static const _tag = 'PrincipalScope';

  /// `code` del 403 de un principal supervisado o de dispositivo.
  static const scopeDeniedCode = 'PRINCIPAL_SCOPE_DENIED';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 403) {
      final data = err.response?.data;
      if (data is Map && data['code'] == scopeDeniedCode) {
        AppLogger.w('Ruta fuera del alcance del principal, refrescando modo',
            tag: _tag);
        try {
          onScopeDenied?.call();
        } catch (e) {
          // El aviso nunca debe romper la cadena de errores.
          AppLogger.e('Error al refrescar el modo', tag: _tag, error: e);
        }
      }
    }
    handler.next(err);
  }
}
