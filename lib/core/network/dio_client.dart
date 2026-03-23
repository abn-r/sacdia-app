import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logger_interceptor.dart';
import 'interceptors/error_interceptor.dart';

/// Cliente HTTP configurado con DIO según los requisitos
///
/// SECURITY NOTE — TLS / Certificate Pinning:
/// Full certificate pinning is not implemented because the backend runs on
/// Render.com (shared hosting), where TLS certificates rotate automatically
/// and are managed by the platform. Pinning to a specific certificate SHA-256
/// would break the app on every certificate renewal.
/// Mitigation: HTTPS is enforced via the defaultBaseUrl (no plain HTTP in
/// production) and Dio will reject connections that fail standard TLS
/// validation. Revisit certificate pinning if the backend moves to a
/// dedicated host with a stable certificate or uses a public-key pin.
class DioClient {
  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: Duration(seconds: AppConstants.connectTimeout),
      sendTimeout: Duration(seconds: AppConstants.sendTimeout),
      receiveTimeout: Duration(seconds: AppConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Añadir interceptores requeridos
    // AuthInterceptor recibe la instancia de Dio para poder reintentar
    // después de refrescar el token en caso de 401
    dio.interceptors.addAll([
      LoggerInterceptor(),
      // AuthInterceptor ANTES de ErrorInterceptor: Dio procesa onError en
      // orden forward (0→1→2→3), así AuthInterceptor intercepta el 401 y
      // refresca el token antes de que ErrorInterceptor lance AuthException.
      AuthInterceptor(dio: dio),
      ErrorInterceptor(),
      // RetryInterceptor después de AuthInterceptor para que los reintentos
      // incluyan los headers de autenticación actualizados.
      RetryInterceptor(
        dio: dio,
        retries: 3,
        retryDelays: const [
          Duration(milliseconds: 500),
          Duration(milliseconds: 1500),
          Duration(milliseconds: 3000),
        ],
      ),
    ]);

    return dio;
  }
}

/// Interceptor para reintentar automáticamente solicitudes fallidas
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int retries;
  final List<Duration> retryDelays;
  
  RetryInterceptor({
    required this.dio,
    this.retries = 3,
    required this.retryDelays,
  });
  
  @override
  Future onError(DioException err, ErrorInterceptorHandler handler) async {
    var extra = err.requestOptions.extra;
    var retryCount = extra['retryCount'] ?? 0;
    
    // Reintentar solo para errores de conexión y con códigos de error específicos
    if (_shouldRetry(err) && retryCount < retries) {
      // Incrementar contador de reintentos
      extra['retryCount'] = retryCount + 1;
      
      // Esperar antes de reintentar
      if (retryCount < retryDelays.length) {
        await Future.delayed(retryDelays[retryCount]);
      }
      
      // Crear nueva solicitud
      final options = Options(
        method: err.requestOptions.method,
        headers: err.requestOptions.headers,
        extra: extra,
      );
      
      try {
        final response = await dio.request(
          err.requestOptions.path,
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
          options: options,
        );
        return handler.resolve(response);
      } catch (e) {
        return handler.next(err);
      }
    }
    
    return handler.next(err);
  }
  
  bool _shouldRetry(DioException err) {
    // Only retry idempotent HTTP methods. Retrying POST or PATCH risks
    // duplicate writes (e.g. double-creating a record on a transient error).
    final isIdempotent = ['GET', 'HEAD', 'DELETE', 'PUT']
        .contains(err.requestOptions.method.toUpperCase());
    if (!isIdempotent) return false;

    return err.type == DioExceptionType.connectionTimeout ||
           err.type == DioExceptionType.receiveTimeout ||
           err.type == DioExceptionType.sendTimeout ||
           err.type == DioExceptionType.connectionError ||
           (err.response?.statusCode != null &&
            err.response!.statusCode! >= 500 &&
            err.response!.statusCode! < 600);
  }
}
