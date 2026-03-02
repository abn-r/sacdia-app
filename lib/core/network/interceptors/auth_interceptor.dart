import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../constants/app_constants.dart';
import '../../utils/app_logger.dart';

/// Interceptor para añadir token de autenticación a las peticiones
class AuthInterceptor extends QueuedInterceptor {
  final FlutterSecureStorage _secureStorage;
  final Dio? _dio;

  static const _tag = 'AuthInterceptor';

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
    final token = await _secureStorage.read(key: AppConstants.tokenKey);

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
    if (err.response?.statusCode == 401 && _dio != null) {
      AppLogger.w('Token expirado, intentando refresh', tag: _tag);

      final refreshed = await _tryRefreshToken();

      if (refreshed) {
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
          AppLogger.e('Error al reintentar después de refresh', tag: _tag, error: e);
        }
      } else {
        AppLogger.w('Refresh fallido, limpiando tokens locales', tag: _tag);
        await _secureStorage.delete(key: AppConstants.tokenKey);
        await _secureStorage.delete(key: AppConstants.refreshTokenKey);
      }
    }

    handler.next(err);
  }

  /// Intenta refrescar el token usando el refresh token almacenado
  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: AppConstants.refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.w('Sin refresh token disponible', tag: _tag);
        return false;
      }

      final response = await Dio().post(
        '${AppConstants.baseUrl}/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.data;
        final innerData = responseBody['data'] as Map<String, dynamic>?;
        final newAccessToken = innerData?['accessToken'] as String?;
        final newRefreshToken = innerData?['refreshToken'] as String?;

        if (newAccessToken != null) {
          await _secureStorage.write(
            key: AppConstants.tokenKey,
            value: newAccessToken,
          );
          if (newRefreshToken != null) {
            await _secureStorage.write(
              key: AppConstants.refreshTokenKey,
              value: newRefreshToken,
            );
          }
          AppLogger.i('Token refrescado exitosamente', tag: _tag);
          return true;
        }
      }

      AppLogger.w('Refresh token falló: ${response.statusCode}', tag: _tag);
      return false;
    } catch (e) {
      AppLogger.e('Error en refresh token', tag: _tag, error: e);
      return false;
    }
  }
}
