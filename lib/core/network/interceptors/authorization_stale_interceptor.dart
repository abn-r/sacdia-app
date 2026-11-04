import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../utils/app_logger.dart';

/// Código de negocio con el que la app rechaza una mutación mientras la
/// autorización del usuario es la de la caché (`UserEntity.authorizationStale`).
/// Tiene traducción en `errors.authorization_stale` (ver `userErrorMessage`).
const String kAuthorizationStaleCode = 'AUTHORIZATION_STALE';

/// Clave de `RequestOptions.extra` para dejar pasar una mutación concreta
/// aunque la autorización sea obsoleta (p. ej. una petición de sesión).
const String kAllowWhileAuthorizationStale = 'allow_while_authorization_stale';

/// Bloquea las mutaciones (POST, PUT, PATCH, DELETE) mientras la sesión se
/// restauró sin red y la autorización en memoria es la de la caché.
///
/// Lo que el usuario podía hacer pudo cambiar sin que la app lo sepa: hasta
/// que `/auth/me` vuelva a responder (`AuthNotifier.refreshAuthorization`) solo
/// se lee. La petición nunca sale: se rechaza con un `DioException` cuyo cuerpo
/// lleva `code: AUTHORIZATION_STALE` y estado 403, así cualquier mapeador de la
/// capa de datos (`businessErrorFrom`, `rethrowApiError`...) la convierte en
/// un fallo con ese `errorCode` y la UI muestra `errors.authorization_stale`.
///
/// No toca los GET ni las rutas de sesión ([sessionPaths]: refresco del
/// token, cierre de sesión, la propia sesión y su contexto), y no tiene nada
/// que ver con `ACTING_FOR_*` ni con `PRINCIPAL_SCOPE_*`: no lee ni cambia el
/// modo «actuar por» ni el principal.
class AuthorizationStaleInterceptor extends Interceptor {
  AuthorizationStaleInterceptor({required this.isStale});

  /// ¿La autorización vigente viene de la caché?
  final bool Function() isStale;

  static const _tag = 'AuthorizationStale';
  static const _mutations = {'POST', 'PUT', 'PATCH', 'DELETE'};

  /// Rutas de sesión que siguen funcionando con la autorización obsoleta: no
  /// son acciones de negocio. Es una lista explícita, nunca `/auth/*` entero:
  /// cualquier otra mutación bajo `/auth/` (p. ej. `/auth/update-password`)
  /// se bloquea como las demás.
  static const Set<String> sessionPaths = {
    // Renovar el token (AuthInterceptor).
    '/auth/refresh',
    // Cerrar sesión.
    '/auth/logout',
    // La propia sesión (`DELETE /auth/me`).
    '/auth/me',
    // Cambiar el contexto activo (`PATCH /auth/me/context`).
    '/auth/me/context',
  };

  /// ¿[options] apunta a una de [sessionPaths]? Compara por sufijo del path
  /// normalizado: la URI resuelta contra la base (los datasources pasan rutas
  /// relativas y absolutas), sin query ni `/` final. Nunca por `contains`.
  static bool isSessionPath(RequestOptions options) {
    final path = _normalizedPath(options);
    return sessionPaths.any((s) => path == s || path.endsWith(s));
  }

  static String _normalizedPath(RequestOptions options) {
    String path;
    try {
      path = options.uri.path;
    } catch (_) {
      path = options.path.split('?').first;
    }
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path.startsWith('/') ? path : '/$path';
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final method = options.method.toUpperCase();
    if (!_mutations.contains(method) ||
        options.extra[kAllowWhileAuthorizationStale] == true ||
        isSessionPath(options)) {
      handler.next(options);
      return;
    }
    bool stale;
    try {
      stale = isStale();
    } catch (e) {
      // La comprobación nunca debe romper una petición.
      AppLogger.e('Error al comprobar la autorización', tag: _tag, error: e);
      stale = false;
    }
    if (!stale) {
      handler.next(options);
      return;
    }
    AppLogger.w(
      'Mutación $method ${options.path} rechazada: autorización obsoleta',
      tag: _tag,
    );
    final message = tr('errors.authorization_stale');
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        message: message,
        response: Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 403,
          data: <String, dynamic>{
            'code': kAuthorizationStaleCode,
            'message': message,
          },
        ),
      ),
    );
  }
}
