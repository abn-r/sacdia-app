import 'package:equatable/equatable.dart';

/// Clase base para todos los fallos en la aplicación
abstract class Failure extends Equatable {
  final String message;
  final int? code;
  final StackTrace? stackTrace;

  const Failure({
    required this.message,
    this.code,
    this.stackTrace,
  });

  @override
  List<Object?> get props => [message, code, stackTrace];
}

// Fallos específicos del servidor
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.code,
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
  const AuthFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
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

/// Señal (no un error real) que indica que el flujo OAuth fue iniciado.
/// La UI debe mostrar un estado informativo, no un error.
class OAuthFlowInitiatedFailure extends Failure {
  /// Nombre del proveedor OAuth ("Google", "Apple", etc.).
  final String provider;

  const OAuthFlowInitiatedFailure({
    required this.provider,
  }) : super(
          message:
              'Redirigiendo a $provider. Completa el proceso en el navegador.',
        );

  @override
  List<Object?> get props => [...super.props, provider];
}
