import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../constants/app_constants.dart';
import '../../utils/app_logger.dart';

/// Interceptor responsable de:
/// 1. Adjuntar el Bearer token a cada petición autenticada.
/// 2. Detectar respuestas 401 y realizar un refresh reactivo de token.
/// 3. Reintentar la petición original exactamente una vez tras un refresh exitoso.
/// 4. Prevenir bucles infinitos de refresh/retry marcando la request con una
///    bandera en `extra`.
class AuthInterceptor extends QueuedInterceptor {
  final FlutterSecureStorage _secureStorage;

  /// Instancia Dio separada para las llamadas de refresh, de modo que no
  /// pasen por este mismo interceptor y no generen bucles.
  final Dio _refreshDio;

  static const _tag = 'AuthInterceptor';

  /// Clave usada en `RequestOptions.extra` para marcar que la petición ya fue
  /// reintentada después de un refresh, evitando bucles infinitos.
  static const _retryAfterRefreshKey = 'auth_interceptor_retry_after_refresh';

  AuthInterceptor({
    FlutterSecureStorage? secureStorage,
    /// La instancia principal de Dio (con interceptores). Se mantiene para
    /// reintentar la petición original después del refresh.
    Dio? dio,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _refreshDio = _buildRefreshDio();

  static Dio _buildRefreshDio() {
    return Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout:
          Duration(seconds: AppConstants.connectTimeout),
      receiveTimeout:
          Duration(seconds: AppConstants.receiveTimeout),
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
    final token =
        await _secureStorage.read(key: AppConstants.tokenKey);

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
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

    // Si esta petición ya fue reintentada, no entrar en bucle.
    final isRetry =
        err.requestOptions.extra[_retryAfterRefreshKey] == true;
    if (isRetry) {
      AppLogger.w(
          'Refresh/retry fallido en segundo intento, descartando sesión',
          tag: _tag);
      await _clearTokens();
      return handler.next(err);
    }

    AppLogger.w('401 detectado, intentando refresh reactivo', tag: _tag);

    final refreshed = await _tryRefreshToken();

    if (!refreshed) {
      AppLogger.w('Refresh reactivo fallido, limpiando tokens', tag: _tag);
      await _clearTokens();
      return handler.next(err);
    }

    // Refresh exitoso: reintentar la petición original UNA vez.
    try {
      final newToken =
          await _secureStorage.read(key: AppConstants.tokenKey);

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
        validateStatus: (s) => s != null,
      ));

      final response = await retryDio.request(
        err.requestOptions.path,
        data: err.requestOptions.data,
        queryParameters: err.requestOptions.queryParameters,
        options: retryOptions,
      );

      return handler.resolve(response);
    } catch (e) {
      AppLogger.e('Error al reintentar después de refresh', tag: _tag, error: e);
      return handler.next(err);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Realiza el refresh usando el refresh token almacenado.
  /// Guarda los nuevos tokens si el servidor responde con éxito.
  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken =
          await _secureStorage.read(key: AppConstants.refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.w('Sin refresh token disponible', tag: _tag);
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
                key: AppConstants.expiresAtKey,
                value: newExpiresAt.toString());
          }
          if (newTokenType != null) {
            await _secureStorage.write(
                key: AppConstants.tokenTypeKey, value: newTokenType);
          }
          AppLogger.i('Token refrescado exitosamente (interceptor)', tag: _tag);
          return true;
        }
      }

      AppLogger.w('Refresh token falló: ${response.statusCode}', tag: _tag);
      return false;
    } catch (e) {
      AppLogger.e('Error en refresh token (interceptor)', tag: _tag, error: e);
      return false;
    }
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _secureStorage.delete(key: AppConstants.expiresAtKey);
    await _secureStorage.delete(key: AppConstants.tokenTypeKey);
  }
}
