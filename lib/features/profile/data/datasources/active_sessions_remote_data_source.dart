import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/active_session_model.dart';

/// Interfaz del datasource remoto de sesiones activas.
abstract class ActiveSessionsRemoteDataSource {
  /// GET /auth/sessions
  Future<List<ActiveSessionModel>> getSessions();

  /// DELETE /auth/sessions/:sessionId
  Future<void> revokeSession(String sessionId);

  /// DELETE /auth/sessions
  /// Retorna la cantidad de sesiones revocadas.
  Future<int> revokeAllOtherSessions();
}

/// Implementación con Dio.
class ActiveSessionsRemoteDataSourceImpl
    implements ActiveSessionsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'ActiveSessionsDS';

  ActiveSessionsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<List<ActiveSessionModel>> getSessions() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.auth}/sessions',
      );

      if (response.statusCode != 200) {
        throw ServerException(
          message: tr('profile.active_sessions.errors.get_sessions'),
          code: response.statusCode,
        );
      }

      final data = response.data;
      final List<dynamic> sessions;

      if (data is Map<String, dynamic>) {
        sessions = data['sessions'] as List<dynamic>? ?? [];
      } else {
        throw ServerException(
            message: tr('profile.active_sessions.errors.get_sessions_format'));
      }

      return sessions
          .whereType<Map<String, dynamic>>()
          .map(ActiveSessionModel.fromJson)
          .toList();
    } on ServerException {
      rethrow;
    } on DioException catch (e) {
      AppLogger.w(
        'Error HTTP al obtener sesiones (${e.response?.statusCode})',
        tag: _tag,
        error: e,
      );
      _throwMappedError(
          e,
          defaultMessage:
              tr('profile.active_sessions.errors.get_sessions'));
    } catch (e) {
      AppLogger.e('Error inesperado al obtener sesiones', tag: _tag, error: e);
      throw ServerException(
          message: '${tr('profile.active_sessions.errors.unexpected')}: $e');
    }
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.auth}/sessions/$sessionId',
      );

      // 204 No Content = éxito
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw ServerException(
          message: tr('profile.active_sessions.errors.revoke_session'),
          code: response.statusCode,
        );
      }
    } on ServerException {
      rethrow;
    } on DioException catch (e) {
      AppLogger.w(
        'Error HTTP al revocar sesión $sessionId (${e.response?.statusCode})',
        tag: _tag,
        error: e,
      );
      _throwMappedError(
          e,
          defaultMessage:
              tr('profile.active_sessions.errors.revoke_session'));
    } catch (e) {
      AppLogger.e('Error inesperado al revocar sesión', tag: _tag, error: e);
      throw ServerException(
          message: '${tr('profile.active_sessions.errors.unexpected')}: $e');
    }
  }

  @override
  Future<int> revokeAllOtherSessions() async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.auth}/sessions',
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException(
          message: tr('profile.active_sessions.errors.revoke_all'),
          code: response.statusCode,
        );
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return (data['revoked_count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } on ServerException {
      rethrow;
    } on DioException catch (e) {
      AppLogger.w(
        'Error HTTP al revocar todas las sesiones (${e.response?.statusCode})',
        tag: _tag,
        error: e,
      );
      _throwMappedError(
          e,
          defaultMessage: tr('profile.active_sessions.errors.revoke_all'));
    } catch (e) {
      AppLogger.e(
          'Error inesperado al revocar todas las sesiones', tag: _tag, error: e);
      throw ServerException(
          message: '${tr('profile.active_sessions.errors.unexpected')}: $e');
    }
  }

  /// Mapea errores DioException a [ServerException] con mensajes en español
  /// según el código HTTP del backend.
  Never _throwMappedError(
    DioException e, {
    required String defaultMessage,
  }) {
    final statusCode = e.response?.statusCode;
    final serverMessage = e.response?.data is Map
        ? (e.response!.data['message'] as String?)
        : null;

    final message = switch (statusCode) {
      400 when serverMessage?.contains('logout') == true =>
        tr('profile.active_sessions.errors.revoke_current_forbidden'),
      400 => serverMessage ?? defaultMessage,
      403 => tr('profile.active_sessions.errors.revoke_forbidden'),
      404 => tr('profile.active_sessions.errors.revoke_not_found'),
      429 => tr('profile.active_sessions.errors.too_many_requests'),
      _ => serverMessage ?? defaultMessage,
    };

    throw ServerException(message: message, code: statusCode);
  }
}
