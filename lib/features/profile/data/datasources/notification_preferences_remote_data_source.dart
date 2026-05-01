import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/notification_preferences_model.dart';

/// Interfaz para el datasource remoto de preferencias de notificación.
abstract class NotificationPreferencesRemoteDataSource {
  /// GET /users/me/notification-preferences
  Future<NotificationPreferencesModel> getPreferences();

  /// PATCH /users/me/notification-preferences
  ///
  /// [delta] es un mapa parcial — solo los campos a cambiar.
  Future<NotificationPreferencesModel> updatePreferences(
    Map<String, bool> delta,
  );
}

/// Implementación con Dio.
class NotificationPreferencesRemoteDataSourceImpl
    implements NotificationPreferencesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'NotifPrefsDS';

  NotificationPreferencesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<NotificationPreferencesModel> getPreferences() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/me/notification-preferences',
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr(
            'profile.notification_preferences.errors.get_status',
          ),
          code: response.statusCode,
        );
      }

      final data = _extractData(response.data);
      return NotificationPreferencesModel.fromJson(data);
    } on ServerException {
      rethrow;
    } on DioException catch (e) {
      AppLogger.w(
        'Error HTTP al obtener preferencias (${e.response?.statusCode})',
        tag: _tag,
        error: e,
      );
      throw ServerException(
        message: e.response?.data is Map
            ? (e.response!.data['message'] as String? ??
                tr('profile.notification_preferences.errors.get_http'))
            : tr('profile.notification_preferences.errors.get_http'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error inesperado al obtener preferencias', tag: _tag, error: e);
      throw ServerException(
        message:
            '${tr('profile.notification_preferences.errors.get_unexpected')}: $e',
      );
    }
  }

  @override
  Future<NotificationPreferencesModel> updatePreferences(
    Map<String, bool> delta,
  ) async {
    try {
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.users}/me/notification-preferences',
        data: delta,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr(
            'profile.notification_preferences.errors.update_status',
          ),
          code: response.statusCode,
        );
      }

      final data = _extractData(response.data);
      return NotificationPreferencesModel.fromJson(data);
    } on ServerException {
      rethrow;
    } on DioException catch (e) {
      AppLogger.w(
        'Error HTTP al actualizar preferencias (${e.response?.statusCode})',
        tag: _tag,
        error: e,
      );
      throw ServerException(
        message: e.response?.data is Map
            ? (e.response!.data['message'] as String? ??
                tr('profile.notification_preferences.errors.update_http'))
            : tr('profile.notification_preferences.errors.update_http'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error inesperado al actualizar preferencias', tag: _tag, error: e);
      throw ServerException(
        message:
            '${tr('profile.notification_preferences.errors.update_unexpected')}: $e',
      );
    }
  }

  /// Extrae el payload relevante del envelope estándar del backend.
  /// El backend puede devolver `{ data: {...} }` o directamente `{...}`.
  Map<String, dynamic> _extractData(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final nested = responseData['data'];
      if (nested is Map<String, dynamic>) return nested;
      return responseData;
    }
    throw ServerException(
      message: tr('profile.notification_preferences.errors.unexpected_format'),
    );
  }
}
