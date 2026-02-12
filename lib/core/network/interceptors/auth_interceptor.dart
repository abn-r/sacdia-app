import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../constants/app_constants.dart';

/// Interceptor para añadir token de autenticación a las peticiones
class AuthInterceptor extends QueuedInterceptor {
  final FlutterSecureStorage _secureStorage;
  final Dio? _dio;

  AuthInterceptor({
    FlutterSecureStorage? secureStorage,
    Dio? dio,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _dio = dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Obtener el token de FlutterSecureStorage
    final token = await _secureStorage.read(key: AppConstants.tokenKey);

    // Si hay un token válido, lo añadimos a la cabecera
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Manejar errores 401 (Unauthorized) - Token expirado o inválido
    if (err.response?.statusCode == 401 && _dio != null) {
      log('⚠️ [AuthInterceptor] Token inválido o expirado, intentando refresh...');

      // Intentar refresh token
      final refreshed = await _tryRefreshToken();

      if (refreshed) {
        // Reintentar la petición original con el nuevo token
        try {
          final newToken = await _secureStorage.read(key: AppConstants.tokenKey);
          final opts = Options(
            method: err.requestOptions.method,
            headers: {
              ...err.requestOptions.headers,
              'Authorization': 'Bearer $newToken',
            },
          );

          final response = await _dio.request(
            err.requestOptions.path,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
            options: opts,
          );

          return handler.resolve(response);
        } catch (e) {
          log('❌ [AuthInterceptor] Error al reintentar después de refresh: $e');
        }
      }
    }

    handler.next(err);
  }

  /// Intenta refrescar el token usando el refresh_token almacenado
  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: AppConstants.refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        log('⚠️ [AuthInterceptor] No hay refresh token disponible');
        return false;
      }

      // Llamar al endpoint de refresh (sin usar el interceptor para evitar loops)
      final response = await Dio().post(
        '${AppConstants.baseUrl}/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final newAccessToken = data['access_token'] as String?;

        if (newAccessToken != null) {
          await _secureStorage.write(
            key: AppConstants.tokenKey,
            value: newAccessToken,
          );
          log('✅ [AuthInterceptor] Token refrescado exitosamente');
          return true;
        }
      }

      log('❌ [AuthInterceptor] Refresh token falló: ${response.statusCode}');
      return false;
    } catch (e) {
      log('❌ [AuthInterceptor] Error en refresh token: $e');
      return false;
    }
  }
}
