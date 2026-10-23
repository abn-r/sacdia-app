import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../errors/exceptions.dart';

/// Excepción tipada a partir de una respuesta de error del backend.
///
/// Conserva el `code` de negocio (`GUARDIANSHIP_*`, `MR_*`, ...) del cuerpo para
/// que la UI muestre el mensaje exacto. `details` no se lee nunca: el backend lo
/// omite en producción (RULING #11528).
AppException appExceptionFromResponse(
  int? status,
  Object? data, {
  String? fallback,
}) {
  String? message;
  String? errorCode;
  if (data is Map) {
    message = data['message']?.toString();
    errorCode = data['code']?.toString();
  }
  final resolved = message ?? fallback ?? tr('errors.server_error');
  if (status == 401 || status == 403) {
    return AuthException(
      message: resolved,
      code: status,
      errorCode: errorCode,
    );
  }
  return ServerException(
    message: resolved,
    code: status,
    errorCode: errorCode,
  );
}

/// Convierte cualquier error de una llamada HTTP en una [AppException] que
/// conserva el `code` de negocio. Nunca devuelve: siempre lanza.
Never rethrowApiError(Object e) {
  if (e is AppException) throw e;
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionException(
        message: e.message ?? tr('errors.connection_error'),
        stackTrace: e.stackTrace,
      );
    }
    // El ErrorInterceptor ya tradujo el error; se rescata el `code` de la
    // respuesta.
    throw appExceptionFromResponse(
      e.response?.statusCode,
      e.response?.data,
      fallback: e.message,
    );
  }
  throw ServerException(message: e.toString());
}
