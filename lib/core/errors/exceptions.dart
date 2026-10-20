import 'package:easy_localization/easy_localization.dart';

/// Clase base para todas las excepciones de la aplicación
class AppException implements Exception {
  final String message;
  final int? code;

  /// Código de negocio del backend (p. ej. `INVESTITURE_REQUEST_FORBIDDEN`),
  /// distinto de [code], que es el estado HTTP.
  final String? errorCode;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.code,
    this.errorCode,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException: $message (Code: $code)';
}

// Excepciones del servidor
class ServerException extends AppException {
  ServerException({
    required super.message,
    super.code,
    super.errorCode,
    super.stackTrace,
  });
}

// Excepciones de conexión
class ConnectionException extends AppException {
  ConnectionException({
    required super.message,
    super.stackTrace,
  });
}

// Excepciones de caché
class CacheException extends AppException {
  CacheException({
    required super.message,
    super.stackTrace,
  });
}

// Excepciones de autenticación
class AuthException extends AppException {
  /// Segundos que indicó el encabezado `Retry-After` (bloqueo de login, 429).
  /// Nunca sale del cuerpo del error: ahí vive `details`, que no se lee.
  final int? retryAfterSeconds;

  AuthException({
    required super.message,
    super.code,
    super.errorCode,
    super.stackTrace,
    this.retryAfterSeconds,
  });
}

// Excepciones de validación de datos
class ValidationException extends AppException {
  final Map<String, String>? fieldsErrors;

  ValidationException({
    required super.message,
    this.fieldsErrors,
    super.stackTrace,
  });
}

// Excepción de recurso no encontrado (HTTP 404)
class NotFoundException extends AppException {
  NotFoundException({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

/// El usuario cerró la hoja nativa de Google/Apple sin completar el login.
/// No es un error: la UI vuelve al login sin mensaje.
class SocialSignInCancelledException extends AppException {
  SocialSignInCancelledException()
      : super(message: tr('errors.social_signin_cancelled'));
}
