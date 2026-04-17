import 'dart:io';
import 'package:dio/dio.dart';
import '../../errors/exceptions.dart';

/// Interceptor para transformar errores de Dio en excepciones de la aplicación
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Transformar errores de Dio en excepciones manejables de la aplicación
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: ConnectionException(
              message: 'Tiempo de espera agotado. Compruebe su conexión.',
              stackTrace: err.stackTrace,
            ),
            type: err.type,
          ),
        );

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final responseData = err.response?.data;
        String message = 'Error del servidor';

        if (responseData is Map<String, dynamic>) {
          message = responseData['message'] ?? message;
        }

        if (statusCode == 401 || statusCode == 403) {
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: AuthException(
                message: message,
                code: statusCode,
                stackTrace: err.stackTrace,
              ),
              type: err.type,
              response: err.response,
            ),
          );
        } else if (statusCode == 422) {
          // Errores de validación
          Map<String, String>? fieldsErrors;
          if (responseData is Map<String, dynamic> &&
              responseData.containsKey('errors') &&
              responseData['errors'] is Map) {
            fieldsErrors = (responseData['errors'] as Map).map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            );
          }

          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: ValidationException(
                message: message,
                fieldsErrors: fieldsErrors,
                stackTrace: err.stackTrace,
              ),
              type: err.type,
              response: err.response,
            ),
          );
        } else {
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: ServerException(
                message: message,
                code: statusCode,
                stackTrace: err.stackTrace,
              ),
              type: err.type,
              response: err.response,
            ),
          );
        }

      case DioExceptionType.cancel:
        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: ServerException(
              message: 'Solicitud cancelada',
              stackTrace: err.stackTrace,
            ),
            type: err.type,
          ),
        );

      case DioExceptionType.connectionError:
        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: ConnectionException(
              message: 'Error de conexión. Compruebe su red.',
              stackTrace: err.stackTrace,
            ),
            type: err.type,
          ),
        );

      case DioExceptionType.unknown:
        if (err.error is SocketException) {
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: ConnectionException(
                message: 'No hay conexión a Internet',
                stackTrace: err.stackTrace,
              ),
              type: err.type,
            ),
          );
        }
        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: ServerException(
              message: 'Error inesperado: ${err.message}',
              stackTrace: err.stackTrace,
            ),
            type: err.type,
          ),
        );

      case DioExceptionType.badCertificate:
        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: ServerException(
              message: 'Certificado SSL no válido',
              stackTrace: err.stackTrace,
            ),
            type: err.type,
          ),
        );
    }
  }
}
