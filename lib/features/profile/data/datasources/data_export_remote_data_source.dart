import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/data_export_model.dart';

/// Interfaz del datasource remoto de exportaciones de datos.
abstract class DataExportRemoteDataSource {
  /// POST /users/me/data-export
  /// Retorna el modelo de la exportación creada o reutilizada.
  Future<DataExportModel> requestExport();

  /// GET /users/me/data-exports
  /// Retorna la lista de exportaciones del usuario.
  Future<List<DataExportModel>> getExports();

  /// GET /users/me/data-exports/:exportId/download
  /// Retorna la URL presignada de descarga.
  Future<String> getDownloadUrl(String exportId);
}

/// Implementación con Dio.
class DataExportRemoteDataSourceImpl implements DataExportRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'DataExportDS';

  DataExportRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  // ── Paths ──────────────────────────────────────────────────────────────────

  String get _exportPath => '$_baseUrl${ApiEndpoints.users}/me/data-export';
  String get _exportsPath => '$_baseUrl${ApiEndpoints.users}/me/data-exports';
  String _downloadPath(String id) =>
      '$_baseUrl${ApiEndpoints.users}/me/data-exports/$id/download';

  // ── Methods ────────────────────────────────────────────────────────────────

  @override
  Future<DataExportModel> requestExport() async {
    try {
      final response = await _dio.post(
        _exportPath,
        data: {'format': 'json'},
      );

      // 201 = nueva; 200 = reutilizada en curso
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw ServerException(
          message: tr('profile.data_export.errors.request_failed'),
          code: response.statusCode,
        );
      }

      final data = response.data as Map<String, dynamic>;
      return DataExportModel.fromJson(data);
    } on ServerException {
      rethrow;
    } on DioException catch (e) {
      AppLogger.w(
        'Error HTTP al solicitar exportación (${e.response?.statusCode})',
        tag: _tag,
        error: e,
      );
      _throwMappedRequestError(e);
    } catch (e) {
      AppLogger.e('Error inesperado al solicitar exportación', tag: _tag, error: e);
      throw ServerException(message: tr('profile.data_export.errors.unexpected', namedArgs: {'detail': '$e'}));
    }
  }

  @override
  Future<List<DataExportModel>> getExports() async {
    try {
      final response = await _dio.get(_exportsPath);

      if (response.statusCode != 200) {
        throw ServerException(
          message: tr('profile.data_export.errors.list_failed'),
          code: response.statusCode,
        );
      }

      final data = response.data;
      final List<dynamic> exports;

      if (data is Map<String, dynamic>) {
        exports = data['exports'] as List<dynamic>? ?? [];
      } else {
        throw ServerException(message: tr('profile.data_export.errors.unexpected_format'));
      }

      return exports
          .whereType<Map<String, dynamic>>()
          .map(DataExportModel.fromJson)
          .toList();
    } on ServerException {
      rethrow;
    } on DioException catch (e) {
      AppLogger.w(
        'Error HTTP al obtener exportaciones (${e.response?.statusCode})',
        tag: _tag,
        error: e,
      );
      _throwMappedListError(e);
    } catch (e) {
      AppLogger.e('Error inesperado al obtener exportaciones', tag: _tag, error: e);
      throw ServerException(message: tr('profile.data_export.errors.unexpected', namedArgs: {'detail': '$e'}));
    }
  }

  @override
  Future<String> getDownloadUrl(String exportId) async {
    try {
      final response = await _dio.get(_downloadPath(exportId));

      if (response.statusCode != 200) {
        throw ServerException(
          message: tr('profile.data_export.errors.download_failed'),
          code: response.statusCode,
        );
      }

      final data = response.data as Map<String, dynamic>;
      final url = data['url'] as String?;

      if (url == null || url.isEmpty) {
        throw ServerException(message: tr('profile.data_export.errors.download_not_found'));
      }

      return url;
    } on ServerException {
      rethrow;
    } on DioException catch (e) {
      AppLogger.w(
        'Error HTTP al obtener URL de descarga $exportId (${e.response?.statusCode})',
        tag: _tag,
        error: e,
      );
      _throwMappedDownloadError(e, exportId);
    } catch (e) {
      AppLogger.e(
        'Error inesperado al obtener URL de descarga',
        tag: _tag,
        error: e,
      );
      throw ServerException(message: tr('profile.data_export.errors.unexpected', namedArgs: {'detail': '$e'}));
    }
  }

  // ── Error mappers ──────────────────────────────────────────────────────────

  /// Extrae `retry_after_seconds` del body 429 y lo incluye en el mensaje.
  Never _throwMappedRequestError(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;
    final serverMessage =
        body is Map ? (body['message'] as String?) : null;

    if (statusCode == 429) {
      final retryAfter =
          body is Map ? (body['retry_after_seconds'] as num?)?.toInt() : null;

      String waitMsg;
      if (retryAfter != null && retryAfter > 0) {
        final hours = retryAfter ~/ 3600;
        final minutes = (retryAfter % 3600) ~/ 60;
        if (hours > 0 && minutes > 0) {
          waitMsg = '${hours}h ${minutes}min';
        } else if (hours > 0) {
          waitMsg = '${hours}h';
        } else {
          waitMsg = '${minutes}min';
        }
        throw ServerException(
          message: tr('profile.data_export.errors.rate_limit_wait', namedArgs: {'wait': waitMsg}),
          code: 429,
        );
      }

      throw ServerException(
        message: serverMessage ?? tr('profile.data_export.errors.rate_limit'),
        code: 429,
      );
    }

    final message = switch (statusCode) {
      400 => serverMessage ?? tr('profile.data_export.errors.request_invalid'),
      401 => tr('profile.data_export.errors.request_auth'),
      403 => tr('profile.data_export.errors.request_forbidden'),
      _ => serverMessage ?? tr('common.error_network'),
    };

    throw ServerException(message: message, code: statusCode);
  }

  Never _throwMappedListError(DioException e) {
    final statusCode = e.response?.statusCode;
    final serverMessage = e.response?.data is Map
        ? (e.response!.data['message'] as String?)
        : null;

    final message = switch (statusCode) {
      401 => tr('profile.data_export.errors.list_auth'),
      _ => serverMessage ?? tr('common.error_network'),
    };

    throw ServerException(message: message, code: statusCode);
  }

  Never _throwMappedDownloadError(DioException e, String exportId) {
    final statusCode = e.response?.statusCode;

    final message = switch (statusCode) {
      404 => tr('profile.data_export.errors.download_not_found'),
      409 => tr('profile.data_export.errors.download_conflict'),
      410 => tr('profile.data_export.errors.download_gone'),
      422 => tr('profile.data_export.errors.download_invalid'),
      _ => tr('common.error_network'),
    };

    AppLogger.w(
      'Download $exportId → HTTP $statusCode: $message',
      tag: _tag,
    );

    throw ServerException(message: message, code: statusCode);
  }
}
