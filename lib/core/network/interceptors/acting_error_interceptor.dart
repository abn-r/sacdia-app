import 'package:dio/dio.dart';

import '../../auth/acting_for_session.dart';
import '../../utils/app_logger.dart';
import 'auth_interceptor.dart';

/// Reacciona a los 403 propios de "actuar por" (FP-55).
///
/// - `ACTING_FOR_FORBIDDEN`: el tutor ya no puede actuar por ese dependiente
///   (tutoría revocada, dependiente congelado, ...). Avisa por [onActingForbidden]
///   para que la app salga del modo "actuar por", purgue y vuelva al tutor.
/// - `ACTING_FOR_SCOPE_DENIED`: la ruta no está permitida para este perfil. Es
///   un error de ESA acción: NO se sale del modo y el error sigue su camino.
///
/// Solo se lee el `code` del cuerpo; jamás `details`, que el backend omite en
/// producción (RULING #11528).
///
/// Va después de [ActingGenerationInterceptor]: un 403 de un perfil ya
/// abandonado llega aquí como cancelación y nunca expulsa al perfil nuevo. Aun
/// así se exige que la petición haya salido con `X-Acting-For` igual al
/// dependiente vigente.
class ActingErrorInterceptor extends Interceptor {
  ActingErrorInterceptor(this._session, {this.onActingForbidden});

  final ActingForSession _session;

  /// Recibe el id del dependiente cuyo acceso se perdió.
  final void Function(String dependentUserId)? onActingForbidden;

  static const _tag = 'ActingError';

  static const forbiddenCode = 'ACTING_FOR_FORBIDDEN';
  static const scopeDeniedCode = 'ACTING_FOR_SCOPE_DENIED';

  /// `code` de negocio del cuerpo del error, o `null`.
  static String? errorCodeOf(DioException err) {
    final data = err.response?.data;
    if (data is! Map) return null;
    final code = data['code'];
    return code is String ? code : null;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 403 &&
        errorCodeOf(err) == forbiddenCode &&
        _session.isActing) {
      final sent = err.requestOptions.headers[AuthInterceptor.actingForHeader];
      if (sent is String && sent == _session.dependentUserId) {
        AppLogger.w('Acceso al perfil revocado, saliendo de actuar por',
            tag: _tag);
        try {
          onActingForbidden?.call(sent);
        } catch (e) {
          // El aviso nunca debe romper la cadena de errores.
          AppLogger.e('Error al salir de actuar por', tag: _tag, error: e);
        }
      }
    }
    handler.next(err);
  }
}
