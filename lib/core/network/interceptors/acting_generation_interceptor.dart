import 'package:dio/dio.dart';

import '../../auth/acting_for_session.dart';
import '../../utils/app_logger.dart';

/// Descarta las respuestas que llegan tarde tras un cambio de perfil (FP-54).
///
/// Cada petición se sella con `extra['actingGen']` = generación vigente de
/// [ActingForSession] cuando sale. Si al volver la respuesta (o el error) la
/// generación ya es otra, el usuario cambió de perfil mientras volaba: se
/// rechaza como cancelación y NUNCA llega a repositorios ni cachés. Así los
/// datos de Ana no pueden poblar el estado de Luis, ni escribirse en ningún
/// caché, aunque la respuesta tarde más que el cambio.
///
/// `AuthInterceptor.onRequest` sella la generación en el MISMO tramo síncrono en
/// que decide el encabezado `X-Acting-For` (W2), así que el sello siempre
/// corresponde al encabezado enviado. Aquí solo se comprueba: si entre ese
/// punto y este interceptor el perfil cambió, la petición se rechaza antes de
/// salir. Si no hubo sello (Dio sin `AuthInterceptor`), se sella aquí.
///
/// Va justo DESPUÉS de `AuthInterceptor` y ANTES de `ActingErrorInterceptor` y
/// `ErrorInterceptor`: un 403 de un perfil ya abandonado no debe expulsar al
/// perfil nuevo.
class ActingGenerationInterceptor extends Interceptor {
  ActingGenerationInterceptor(this._session);

  final ActingForSession _session;

  static const _tag = 'ActingGeneration';

  /// Clave de `RequestOptions.extra` con la generación con la que salió.
  static const generationKey = 'actingGen';

  /// Razón con la que se rechazan las respuestas obsoletas.
  static const staleReason = 'stale-acting-profile';

  /// Generación con la que se selló [options], o `null` si no se selló.
  static int? generationOf(RequestOptions options) {
    final value = options.extra[generationKey];
    return value is int ? value : null;
  }

  bool _isStale(RequestOptions options) {
    final stamped = generationOf(options);
    return stamped != null && stamped != _session.generation;
  }

  DioException _stale(RequestOptions options) => DioException.requestCancelled(
        requestOptions: options,
        reason: staleReason,
      );

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Un reintento (refresh de token, RetryInterceptor) conserva el sello
    // original: si el perfil cambió mientras tanto ni siquiera se envía.
    if (_isStale(options)) {
      AppLogger.d('Petición obsoleta descartada antes de enviar', tag: _tag);
      return handler.reject(_stale(options));
    }
    options.extra.putIfAbsent(generationKey, () => _session.generation);
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    if (_isStale(options)) {
      AppLogger.d('Respuesta obsoleta descartada: ${options.path}', tag: _tag);
      // `true`: el resto de la cadena de errores la trata como una cancelación
      // normal y la capa de datos recibe la misma forma de error de siempre.
      return handler.reject(_stale(options), true);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type != DioExceptionType.cancel && _isStale(err.requestOptions)) {
      AppLogger.d(
        'Error obsoleto descartado: ${err.requestOptions.path}',
        tag: _tag,
      );
      return handler.next(_stale(err.requestOptions));
    }
    handler.next(err);
  }
}
