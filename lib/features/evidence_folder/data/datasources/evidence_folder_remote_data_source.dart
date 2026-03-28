import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/evidence_file_model.dart';
import '../models/evidence_folder_model.dart';

/// Interfaz para la fuente de datos remota de carpeta de evidencias.
abstract class EvidenceFolderRemoteDataSource {
  Future<EvidenceFolderModel> getEvidenceFolder(String clubSectionId);

  Future<void> submitSection(String clubSectionId, String sectionId);

  Future<EvidenceFileModel> uploadFile({
    required String clubSectionId,
    required String sectionId,
    required String filePath,
    required String fileName,
    required String mimeType,
    void Function(double)? onProgress,
  });

  Future<void> deleteFile({
    required String clubSectionId,
    required String sectionId,
    required String fileId,
  });
}

/// Implementación de la fuente de datos remota de carpeta de evidencias.
///
/// Utiliza Dio para llamadas REST al backend SACDIA.
/// Auth token se lee desde [FlutterSecureStorage] siguiendo el mismo patrón
/// que el resto de datasources de la aplicación.
class EvidenceFolderRemoteDataSourceImpl
    implements EvidenceFolderRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'EvidenceFolderDS';

  EvidenceFolderRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  Future<String> _getAuthToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) throw AuthException(message: 'No hay sesión activa');
    return token;
  }

  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  // ── GET /club-sections/:id/evidence-folder ─────────────────────────────────

  @override
  Future<EvidenceFolderModel> getEvidenceFolder(
      String clubSectionId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubSections}/$clubSectionId/evidence-folder',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        // El backend puede envolver en { data: {...} }
        final folderJson =
            body.containsKey('data') ? body['data'] as Map<String, dynamic> : body;
        return EvidenceFolderModel.fromJson(folderJson);
      }

      throw ServerException(
        message: 'Error al obtener la carpeta de evidencias',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getEvidenceFolder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /club-sections/:id/evidence-folder/sections/:sectionId/submit ─────

  @override
  Future<void> submitSection(
      String clubSectionId, String sectionId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubSections}/$clubSectionId/evidence-folder/sections/$sectionId/submit',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) return;

      throw ServerException(
        message: 'Error al enviar la sección a validación',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en submitSection', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /club-sections/:id/evidence-folder/sections/:sectionId/files ──────

  @override
  Future<EvidenceFileModel> uploadFile({
    required String clubSectionId,
    required String sectionId,
    required String filePath,
    required String fileName,
    required String mimeType,
    void Function(double)? onProgress,
  }) async {
    try {
      final token = await _getAuthToken();

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubSections}/$clubSectionId/evidence-folder/sections/$sectionId/files',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final fraction = sent / total;
            onProgress?.call(fraction);
            AppLogger.d(
              'Upload progress: ${(fraction * 100).toStringAsFixed(1)}%',
              tag: _tag,
            );
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final fileJson = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return EvidenceFileModel.fromJson(fileJson);
      }

      throw ServerException(
        message: 'Error al subir el archivo',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en uploadFile', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /club-sections/:id/evidence-folder/sections/:sectionId/files/:fileId

  @override
  Future<void> deleteFile({
    required String clubSectionId,
    required String sectionId,
    required String fileId,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.clubSections}/$clubSectionId/evidence-folder/sections/$sectionId/files/$fileId',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
        message: 'Error al eliminar el archivo',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en deleteFile', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Error helper ─────────────────────────────────────────────────────────────

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
        return (data['message'] ?? e.message ?? 'Error de conexión').toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? 'Error de conexión';
  }
}
