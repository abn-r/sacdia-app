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
        throw ConnectionException(
          message: 'Tiempo de espera agotado. Compruebe su conexión.',
          stackTrace: err.stackTrace,
        );
        
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final responseData = err.response?.data;
        String message = 'Error del servidor';
        
        if (responseData is Map<String, dynamic>) {
          message = responseData['message'] ?? message;
        }
        
        if (statusCode == 401 || statusCode == 403) {
          throw AuthException(
            message: message,
            code: statusCode,
            stackTrace: err.stackTrace,
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
          
          throw ValidationException(
            message: message,
            fieldsErrors: fieldsErrors,
            stackTrace: err.stackTrace,
          );
        } else {
          throw ServerException(
            message: message,
            code: statusCode,
            stackTrace: err.stackTrace,
          );
        }
        
      case DioExceptionType.cancel:
        throw ServerException(
          message: 'Solicitud cancelada',
          stackTrace: err.stackTrace,
        );
        
      case DioExceptionType.connectionError:
        throw ConnectionException(
          message: 'Error de conexión. Compruebe su red.',
          stackTrace: err.stackTrace,
        );
        
      case DioExceptionType.unknown:
        if (err.error is SocketException) {
          throw ConnectionException(
            message: 'No hay conexión a Internet',
            stackTrace: err.stackTrace,
          );
        }
        throw ServerException(
          message: 'Error inesperado: ${err.message}',
          stackTrace: err.stackTrace,
        );
        
      case DioExceptionType.badCertificate:
        throw ServerException(
          message: 'Certificado SSL no válido',
          stackTrace: err.stackTrace,
        );
    }
  }
}
