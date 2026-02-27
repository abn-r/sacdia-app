import 'package:dio/dio.dart';
import '../../utils/app_logger.dart';

/// Interceptor HTTP minimalista.
///
/// Imprime una línea por request y una por response/error.
/// El body de la respuesta NO se loguea para evitar ruido;
/// solo se muestra en errores para facilitar el diagnóstico.
class LoggerInterceptor extends Interceptor {
  static const _tag = 'HTTP';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.i(
      '${options.method} ${options.uri.path}',
      tag: _tag,
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.i(
      '${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri.path}',
      tag: _tag,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode ?? err.type.name;
    final body = err.response?.data;

    AppLogger.e(
      '$status ${err.requestOptions.method} ${err.requestOptions.uri.path}',
      tag: _tag,
      error: body ?? err.message,
      stackTrace: err.stackTrace,
    );

    handler.next(err);
  }
}
