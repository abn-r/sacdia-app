import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import 'exceptions.dart';

/// Convierte cualquier error de una llamada Dio en una [AppException] tipada
/// que conserva el `code` de negocio del backend (p. ej.
/// `POST_REG_GUARDIAN_ONLY_REQUIRES_ADULT`).
///
/// Solo se lee `code` y `message`: `details` NUNCA, porque el backend lo omite
/// en producción (ruling #11528).
///
/// - Sin red o con timeout → [ConnectionException].
/// - 401/403 → [AuthException]; el resto → [ServerException].
AppException businessErrorFrom(Object e, {String? fallbackMessage}) {
  if (e is AppException) return e;
  if (e is DioException) {
    // El ErrorInterceptor ya clasificó la falta de red (incluido SocketException
    // con tipo `unknown`): se respeta su mensaje traducido.
    final inner = e.error;
    if (inner is ConnectionException) return inner;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ConnectionException(
        message: e.message ?? tr('errors.connection_error'),
        stackTrace: e.stackTrace,
      );
    }
    return businessErrorFromResponse(
      e.response?.statusCode,
      e.response?.data,
      fallbackMessage: fallbackMessage ?? e.message,
    );
  }
  return ServerException(message: fallbackMessage ?? e.toString());
}

/// Igual que [businessErrorFrom] pero a partir de status + cuerpo ya leídos.
AppException businessErrorFromResponse(
  int? status,
  Object? data, {
  String? fallbackMessage,
}) {
  String? message;
  String? errorCode;
  if (data is Map) {
    message = readableErrorMessage(data['message']);
    errorCode = data['code']?.toString();
  }
  final resolved = message ?? fallbackMessage ?? tr('errors.server_error');
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

/// Texto legible del campo `message` de un error del backend.
///
/// Casi siempre es un String, pero un 400 de validación (class-validator)
/// trae una LISTA de errores por campo (`[{property, constraints: {...}}]`) o
/// de textos. Se toma el primer mensaje de las restricciones para mostrarlo
/// tal cual al usuario. Devuelve `null` si no hay texto aprovechable.
String? readableErrorMessage(Object? message) {
  if (message == null) return null;
  if (message is String) {
    final trimmed = message.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (message is List) {
    for (final item in message) {
      final text =
          item is Map ? _firstConstraint(item) : readableErrorMessage(item);
      if (text != null) return text;
    }
    return null;
  }
  return null;
}

String? _firstConstraint(Map<dynamic, dynamic> error) {
  final constraints = error['constraints'];
  if (constraints is Map) {
    for (final value in constraints.values) {
      final text = readableErrorMessage(value);
      if (text != null) return text;
    }
  }
  final children = error['children'];
  if (children is List && children.isNotEmpty) {
    return readableErrorMessage(children);
  }
  return readableErrorMessage(error['message']);
}
