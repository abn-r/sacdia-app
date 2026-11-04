import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import 'exceptions.dart';
import 'failures.dart';

/// Código de negocio con el que la app rechaza una mutación mientras la
/// autorización del usuario es la de la caché (`UserEntity.authorizationStale`,
/// sesión restaurada sin red). Lo emite `AuthorizationStaleInterceptor` como
/// un 403 sintético `{code, message}` y tiene traducción en
/// `errors.authorization_stale` (ver `userErrorMessage`).
const String kAuthorizationStaleCode = 'AUTHORIZATION_STALE';

/// ¿[error] es el rechazo local `AUTHORIZATION_STALE`? Acepta el
/// `DioException` del interceptor, una [Response], una [AppException] o un
/// [Failure] ya mapeados, o el propio código como texto.
///
/// Los datasources que convierten CUALQUIER 403 en un texto genérico de «sin
/// permiso» deben consultarlo antes de remapear, para no perder el mensaje
/// (`errors.authorization_stale`) ni el código, que la UI usa para explicar
/// que basta con recuperar la red.
bool isAuthorizationStale(Object? error) {
  final String? code = switch (error) {
    String() => error,
    DioException(:final response) => _codeOf(response?.data),
    Response(:final data) => _codeOf(data),
    AppException(:final errorCode) => errorCode,
    Failure(:final errorCode) => errorCode,
    _ => null,
  };
  return code?.trim().toUpperCase() == kAuthorizationStaleCode;
}

String? _codeOf(Object? data) => data is Map ? data['code']?.toString() : null;

/// Mensaje para el usuario del rechazo [e]: el del cuerpo sintético del
/// interceptor (ya traducido) o, si faltara, `errors.authorization_stale`.
String authorizationStaleMessage(DioException e) {
  final data = e.response?.data;
  final message = data is Map ? data['message']?.toString() : null;
  if (message != null && message.isNotEmpty) return message;
  return tr('errors.authorization_stale');
}

/// Excepción tipada del rechazo [e] (403 con `errorCode`
/// [kAuthorizationStaleCode]) para los datasources que lanzan [AuthException]
/// en los 403: el repositorio la convierte en un fallo que conserva el código.
AuthException authorizationStaleException(DioException e) => AuthException(
      message: authorizationStaleMessage(e),
      code: e.response?.statusCode ?? 403,
      errorCode: kAuthorizationStaleCode,
    );
