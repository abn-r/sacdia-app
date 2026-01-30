import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logger_interceptor.dart';
import 'interceptors/error_interceptor.dart';

/// Cliente HTTP configurado con DIO según los requisitos
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
    dio.interceptors.addAll([
      AuthInterceptor(),
      LoggerInterceptor(),
      ErrorInterceptor(),
      // Retry interceptor
      RetryInterceptor(
        dio: dio,
        retries: 3,
        retryDelays: [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
          const Duration(seconds: 3),
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
    return err.type == DioExceptionType.connectionTimeout ||
           err.type == DioExceptionType.receiveTimeout ||
           err.type == DioExceptionType.sendTimeout ||
           err.type == DioExceptionType.connectionError ||
           (err.response?.statusCode != null && 
            err.response!.statusCode! >= 500 && 
            err.response!.statusCode! < 600);
  }
}
