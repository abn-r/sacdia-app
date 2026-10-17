import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/acting_for_session.dart';
import '../../constants/app_constants.dart';
import '../../utils/app_logger.dart';

/// Interceptor responsable de:
/// 1. Adjuntar el Bearer token a cada petición autenticada.
/// 2. Detectar respuestas 401 y realizar un refresh reactivo de token.
/// 3. Reintentar la petición original exactamente una vez tras un refresh exitoso.
/// 4. Prevenir bucles infinitos de refresh/retry marcando la request con una
///    bandera en `extra`.
///
/// IMPORTANTE: los endpoints de autenticación pública (login, register, oauth,
/// refresh) están excluidos del ciclo de refresh. Un 401 en esos paths
/// significa credenciales incorrectas, no una sesión expirada, y debe
/// propagarse tal cual para que la UI muestre el mensaje del servidor.
class AuthInterceptor extends QueuedInterceptor {
  final FlutterSecureStorage _secureStorage;

  /// Instancia Dio separada para las llamadas de refresh, de modo que no
  /// pasen por este mismo interceptor y no generen bucles.
  final Dio _refreshDio;

  static const _tag = 'AuthInterceptor';

  /// Clave usada en `RequestOptions.extra` para marcar que la petición ya fue
  /// reintentada después de un refresh, evitando bucles infinitos.
  static const _retryAfterRefreshKey = 'auth_interceptor_retry_after_refresh';

  /// Lock para evitar race condition cuando múltiples 401 llegan en paralelo.
  /// El primer llamador inicia el refresh; los demás esperan su resultado.
  /// Es `static` para cubrir el caso de múltiples instancias del interceptor.
  static Completer<bool>? _refreshCompleter;

  /// Paths que NO deben pasar por el ciclo de refresh reactivo.
  ///
  /// Un 401 en estos endpoints significa credenciales incorrectas o flujo
  /// inválido — no una sesión expirada. Interceptarlos generaría un intento
  /// de refresh sin sentido y tragaría el mensaje de error del servidor.
  static const _publicAuthPaths = <String>[
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/auth/oauth',
    '/auth/password/reset-request',
    '/auth/reset-password',
  ];

  /// Called once when the refresh token is dead and the session cannot be
  /// recovered. Use this to invalidate the auth state without making API calls.
  final VoidCallback? onAuthExpired;

  /// Perfil por el que se actúa (tutor -> dependiente). Nulo en tests o
  /// instancias de Dio que nunca actúan por otro usuario.
  final ActingForSession? _actingForSession;

  /// Rutas (relativas a la base de la API) que JAMÁS llevan `X-Acting-For`.
  ///
  /// Son cuenta/seguridad del tutor (`/auth/*` de sesión), la gestión de
  /// familia (`/guardianships`) y lo que pertenece al dispositivo o a la
  /// cuenta real (`/fcm-tokens`, preferencias de notificación, exportación).
  /// El backend las rechaza si llevan el encabezado.
  static const actingForSkipPrefixes = <String>[
    '/auth/refresh',
    '/auth/logout',
    '/auth/login',
    '/auth/register',
    '/guardianships',
    '/fcm-tokens',
    '/users/me/notification-preferences',
    '/users/me/data-export',
  ];

  /// Nombre del encabezado que sustituye al principal en el backend.
  static const actingForHeader = 'X-Acting-For';

  /// Clave de `RequestOptions.extra` para que una petición concreta NO lleve
  /// `X-Acting-For` aunque se esté actuando (`extra['skipActingFor'] == true`).
  static const skipActingForKey = 'skipActingFor';

  AuthInterceptor({
    FlutterSecureStorage? secureStorage,

    /// La instancia principal de Dio (con interceptores). Se mantiene para
    /// reintentar la petición original después del refresh.
    Dio? dio,
    this.onAuthExpired,
    ActingForSession? actingForSession,
  })  : _actingForSession = actingForSession,
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                  accessibility:
                      KeychainAccessibility.first_unlock_this_device),
            ),
        _refreshDio = _buildRefreshDio();

  static Dio _buildRefreshDio() {
    return Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: Duration(seconds: AppConstants.connectTimeout),
      receiveTimeout: Duration(seconds: AppConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // No lanzar excepción para 4xx/5xx — manejar manualmente.
      validateStatus: (status) => status != null,
    ));
  }

  // ─── onRequest ────────────────────────────────────────────────────────────

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorage.read(key: AppConstants.tokenKey);

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // ÚNICO punto donde se inyecta X-Acting-For. Se lee la sesión DESPUÉS del
    // await: la decisión del encabezado queda en el mismo tramo síncrono que
    // sella la generación (ver ActingGenerationInterceptor).
    final acting = _actingForSession;
    if (acting != null) {
      final dependentId = acting.dependentUserId;
      if (dependentId != null && _shouldSendActingFor(options)) {
        options.headers[actingForHeader] = dependentId;
      } else {
        // Un reintento o una petición reutilizada no debe arrastrar el
        // encabezado de un perfil anterior.
        options.headers.remove(actingForHeader);
      }
    }

    handler.next(options);
  }

  /// `false` para las rutas exentas y para peticiones marcadas con
  /// `extra['skipActingFor'] == true`.
  static bool _shouldSendActingFor(RequestOptions options) {
    if (options.extra[skipActingForKey] == true) return false;
    final path = apiPathOf(options);
    return !actingForSkipPrefixes.any(path.startsWith);
  }

  /// Ruta de la petición relativa a la base de la API (`/users/...`).
  ///
  /// Los datasources de la app pasan tanto rutas relativas como URLs completas
  /// (`'$baseUrl/auth/me'`), así que se resuelve la URI final y se le quita el
  /// prefijo de la base (p. ej. `/api/v1`).
  @visibleForTesting
  static String apiPathOf(RequestOptions options) {
    var path = options.uri.path;
    final basePath = Uri.tryParse(options.baseUrl)?.path ?? '';
    final trimmedBase = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    if (trimmedBase.isNotEmpty && path.startsWith(trimmedBase)) {
      path = path.substring(trimmedBase.length);
    }
    return path.startsWith('/') ? path : '/$path';
  }

  // ─── onError ──────────────────────────────────────────────────────────────

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Solo procesar 401. Otros errores pasan al siguiente interceptor.
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Endpoints públicos de autenticación: un 401 aquí indica credenciales
    // inválidas o flujo incorrecto — NO una sesión expirada. Dejar pasar el
    // error intacto para que la capa de datos lea el mensaje del servidor.
    final requestPath = err.requestOptions.path;
    final isPublicAuthEndpoint = _publicAuthPaths.any(
      (p) => requestPath.contains(p),
    );
    if (isPublicAuthEndpoint) {
      AppLogger.d(
        '401 en endpoint público ($requestPath), omitiendo refresh reactivo',
        tag: _tag,
      );
      return handler.next(err);
    }

    // Reautenticación rechazada (p. ej. `DELETE /auth/me` con contraseña o
    // idToken inválido): es un fallo de dominio, la sesión sigue vigente.
    // Refrescar y reintentar gastaría otro intento del límite horario y, si el
    // refresh falla, cerraría la sesión desde dentro del diálogo.
    if (_isReauthRejection(err)) {
      AppLogger.d(
        '401 de reautenticación (${err.requestOptions.path}), omitiendo refresh',
        tag: _tag,
      );
      return handler.next(err);
    }

    // Si esta petición ya fue reintentada, no entrar en bucle.
    final isRetry = err.requestOptions.extra[_retryAfterRefreshKey] == true;
    if (isRetry) {
      AppLogger.w(
          'Refresh/retry fallido en segundo intento, descartando sesión',
          tag: _tag);
      await _clearTokens();
      onAuthExpired?.call();
      return handler.next(err);
    }

    AppLogger.w('401 detectado, intentando refresh reactivo', tag: _tag);

    final refreshed = await _tryRefreshToken();

    if (!refreshed) {
      AppLogger.w('Refresh reactivo fallido, limpiando tokens', tag: _tag);
      await _clearTokens();
      onAuthExpired?.call();
      return handler.next(err);
    }

    // Refresh exitoso: reintentar la petición original UNA vez.
    try {
      final newToken = await _secureStorage.read(key: AppConstants.tokenKey);

      final retryOptions = Options(
        method: err.requestOptions.method,
        headers: {
          ...err.requestOptions.headers,
          'Authorization': 'Bearer $newToken',
        },
        extra: {
          ...err.requestOptions.extra,
          _retryAfterRefreshKey: true,
        },
        contentType: err.requestOptions.contentType,
        responseType: err.requestOptions.responseType,
      );

      AppLogger.i('Reintentando petición tras refresh exitoso', tag: _tag);

      // Usamos _refreshDio para que el reintento no pase por QueuedInterceptor
      // y no genere un segundo ciclo de refresh.
      final retryDio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: Duration(seconds: AppConstants.connectTimeout),
        sendTimeout: Duration(seconds: AppConstants.sendTimeout),
        receiveTimeout: Duration(seconds: AppConstants.receiveTimeout),
        // Only treat 2xx as success so that 4xx/5xx responses on the retry
        // are properly surfaced as DioExceptions instead of being silently
        // swallowed by handler.resolve(response).
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ));

      final response = await retryDio.request(
        err.requestOptions.path,
        data: err.requestOptions.data,
        queryParameters: err.requestOptions.queryParameters,
        options: retryOptions,
      );

      return handler.resolve(response);
    } catch (e) {
      AppLogger.e('Error al reintentar después de refresh',
          tag: _tag, error: e);
      return handler.next(err);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// `code` del backend que indica una reautenticación fallida, no una sesión
  /// expirada.
  static const _reauthRejectionCodes = <String>{
    'AUTH_INVALID_PASSWORD',
    'AUTH_INVALID_TOKEN',
  };

  static bool _isReauthRejection(DioException err) {
    final data = err.response?.data;
    if (data is! Map) return false;
    final code = data['code'];
    return code is String && _reauthRejectionCodes.contains(code);
  }

  /// Realiza el refresh usando el refresh token almacenado.
  /// Guarda los nuevos tokens si el servidor responde con éxito.
  ///
  /// Usa un [Completer] estático como lock: si un refresh ya está en curso,
  /// los llamadores posteriores esperan su resultado en lugar de disparar
  /// una segunda petición. Esto evita la race condition cuando múltiples
  /// peticiones reciben 401 simultáneamente.
  Future<bool> _tryRefreshToken() async {
    // Si ya hay un refresh en curso, esperar su resultado sin iniciar otro.
    if (_refreshCompleter != null) {
      AppLogger.d('Refresh ya en curso, esperando resultado…', tag: _tag);
      return _refreshCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken =
          await _secureStorage.read(key: AppConstants.refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.w('Sin refresh token disponible', tag: _tag);
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final data = body is Map<String, dynamic>
            ? (body['data'] as Map<String, dynamic>? ?? body)
            : null;

        final newAccessToken = data?['accessToken'] as String?;
        final newRefreshToken = data?['refreshToken'] as String?;
        final newExpiresAt = data?['expiresAt'] as int?;
        final newTokenType = data?['tokenType'] as String?;

        if (newAccessToken != null) {
          await _secureStorage.write(
              key: AppConstants.tokenKey, value: newAccessToken);
          if (newRefreshToken != null) {
            await _secureStorage.write(
                key: AppConstants.refreshTokenKey, value: newRefreshToken);
          }
          if (newExpiresAt != null) {
            await _secureStorage.write(
                key: AppConstants.expiresAtKey, value: newExpiresAt.toString());
          }
          if (newTokenType != null) {
            await _secureStorage.write(
                key: AppConstants.tokenTypeKey, value: newTokenType);
          }
          AppLogger.i('Token refrescado exitosamente (interceptor)', tag: _tag);
          _refreshCompleter!.complete(true);
          return true;
        }
      }

      AppLogger.w('Refresh token falló: ${response.statusCode}', tag: _tag);
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      AppLogger.e('Error en refresh token (interceptor)', tag: _tag, error: e);
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      // Siempre liberar el lock para que el próximo ciclo de refresh pueda
      // iniciarse. Se ejecuta DESPUÉS de que complete() fue llamado.
      _refreshCompleter = null;
    }
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _secureStorage.delete(key: AppConstants.expiresAtKey);
    await _secureStorage.delete(key: AppConstants.tokenTypeKey);
  }
}
