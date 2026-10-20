import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

/// Clase base para todos los fallos en la aplicación
abstract class Failure extends Equatable implements Exception {
  final String message;
  final int? code;

  /// Código de negocio del backend, distinto de [code] (estado HTTP).
  final String? errorCode;
  final StackTrace? stackTrace;

  const Failure({
    required this.message,
    this.code,
    this.errorCode,
    this.stackTrace,
  });

  @override
  List<Object?> get props => [message, code, errorCode, stackTrace];
}

// Fallos específicos del servidor
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.code,
    super.errorCode,
    super.stackTrace,
  });
}

// Fallos de conexión
class ConnectionFailure extends Failure {
  const ConnectionFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

// Fallos de red
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

// Fallos de caché
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.stackTrace,
  });
}

// Fallos de autenticación
class AuthFailure extends Failure {
  /// Segundos del encabezado `Retry-After` (bloqueo de login, 429).
  final int? retryAfterSeconds;

  const AuthFailure({
    required super.message,
    super.code,
    super.errorCode,
    super.stackTrace,
    this.retryAfterSeconds,
  });

  @override
  List<Object?> get props => [...super.props, retryAfterSeconds];
}

// Fallos de validación de datos
class ValidationFailure extends Failure {
  final Map<String, String>? fieldsErrors;

  const ValidationFailure({
    required super.message,
    this.fieldsErrors,
    super.stackTrace,
  });

  @override
  List<Object?> get props => [...super.props, fieldsErrors];
}

// Fallo de recurso no encontrado (HTTP 404)
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

// Fallos inesperados
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    required super.message,
    super.stackTrace,
  });
}

/// El usuario canceló la hoja nativa de Google/Apple. No se muestra error.
class SocialSignInCancelledFailure extends Failure {
  SocialSignInCancelledFailure()
      : super(message: tr('errors.social_signin_cancelled'));
}
