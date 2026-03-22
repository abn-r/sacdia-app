/// Clase base para todas las excepciones de la aplicación
class AppException implements Exception {
  final String message;
  final int? code;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.code,
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
  AuthException({
    required super.message,
    super.code,
    super.stackTrace,
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

/// Señal (no un error real) que indica que el flujo OAuth fue iniciado
/// correctamente. El resultado de la autenticación llegará de forma
/// asíncrona a través del deep link y [authStateChanges].
class OAuthFlowInitiatedException extends AppException {
  /// Nombre del proveedor OAuth ("Google", "Apple", etc.).
  final String provider;

  OAuthFlowInitiatedException({required this.provider})
      : super(
          message:
              'Redirigiendo a $provider para autenticación. '
              'Regresa a la app tras completar el proceso.',
        );
}
