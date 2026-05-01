import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/annual_folder_model.dart';

/// Interfaz para el data source remoto de carpetas anuales
abstract class AnnualFoldersRemoteDataSource {
  Future<AnnualFolderModel> getFolderByEnrollment(int enrollmentId, {CancelToken? cancelToken});

  Future<FolderEvidenceModel> uploadEvidence(
    int folderId, {
    required int sectionId,
    required String fileUrl,
    required String fileName,
    String? notes,
  });

  Future<void> deleteEvidence(int evidenceId);

  Future<AnnualFolderModel> submitFolder(int folderId);
}

/// Implementación del data source remoto de carpetas anuales
class AnnualFoldersRemoteDataSourceImpl
    implements AnnualFoldersRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'AnnualFoldersDS';

  AnnualFoldersRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Never _rethrow(Object e) {
    if (e is DioException) {
      final msg = _extractDioMessage(e);
      throw ServerException(message: msg, code: e.response?.statusCode);
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is List) return msg.join(', ');
        return (msg ?? e.message ?? tr('common.error_network')).toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? tr('common.error_network');
  }

  // ── GET /api/v1/annual-folders/enrollment/:enrollmentId ──────────────────

  @override
  Future<AnnualFolderModel> getFolderByEnrollment(int enrollmentId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.annualFolders}/enrollment/$enrollmentId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final json = data is Map && data.containsKey('data')
            ? data['data'] as Map<String, dynamic>
            : data as Map<String, dynamic>;
        return AnnualFolderModel.fromJson(json);
      }

      throw ServerException(
          message: tr('annual_folders.errors.get_folder'),
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getFolderByEnrollment', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /api/v1/annual-folders/:folderId/evidences ──────────────────────

  @override
  Future<FolderEvidenceModel> uploadEvidence(
    int folderId, {
    required int sectionId,
    required String fileUrl,
    required String fileName,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'section_id': sectionId,
        'file_url': fileUrl,
        'file_name': fileName,
      };
      if (notes != null) body['notes'] = notes;

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.annualFolders}/$folderId/evidences',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final json = data is Map && data.containsKey('data')
            ? data['data'] as Map<String, dynamic>
            : data as Map<String, dynamic>;
        return FolderEvidenceModel.fromJson(json);
      }

      throw ServerException(
          message: tr('annual_folders.errors.upload_evidence'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en uploadEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /api/v1/annual-folders/evidences/:evidenceId ──────────────────

  @override
  Future<void> deleteEvidence(int evidenceId) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.annualFolders}/evidences/$evidenceId',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
          message: tr('annual_folders.errors.delete_evidence'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en deleteEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /api/v1/annual-folders/:folderId/submit ─────────────────────────

  @override
  Future<AnnualFolderModel> submitFolder(int folderId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.annualFolders}/$folderId/submit',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final json = data is Map && data.containsKey('data')
            ? data['data'] as Map<String, dynamic>
            : data as Map<String, dynamic>;
        return AnnualFolderModel.fromJson(json);
      }

      throw ServerException(
          message: tr('annual_folders.errors.submit_folder'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en submitFolder', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
