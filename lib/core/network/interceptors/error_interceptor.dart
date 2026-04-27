import 'dart:io';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
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
              message: tr('errors.connection_timeout'),
              stackTrace: err.stackTrace,
            ),
            type: err.type,
          ),
        );

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final responseData = err.response?.data;
        String message = tr('errors.server_error');

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
              message: tr('errors.request_cancelled'),
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
              message: tr('errors.connection_error'),
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
                message: tr('errors.no_internet'),
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
              message: tr('errors.unexpected', namedArgs: {'details': err.message ?? ''}),
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
              message: tr('errors.ssl_invalid'),
              stackTrace: err.stackTrace,
            ),
            type: err.type,
          ),
        );
    }
  }
}
