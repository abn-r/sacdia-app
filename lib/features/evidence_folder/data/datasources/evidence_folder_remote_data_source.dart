import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/evidence_file_model.dart';
import '../models/evidence_folder_model.dart';

/// Interfaz para la fuente de datos remota de carpeta de evidencias.
abstract class EvidenceFolderRemoteDataSource {
  /// Obtiene la carpeta anual de una sección de club.
  ///
  /// Usa el endpoint de conveniencia que acepta [clubSectionId] como integer.
  Future<EvidenceFolderModel> getEvidenceFolder(String clubSectionId);

  /// Envía la carpeta completa a validación.
  ///
  /// [folderId] es el UUID de annual_folder_id.
  Future<void> submitFolder(String folderId);

  /// Envía una sección individual a validación.
  ///
  /// [folderId] es el UUID de annual_folder_id.
  /// [sectionId] es el UUID de la sección dentro de la carpeta anual.
  Future<void> submitSection({
    required String folderId,
    required String sectionId,
  });

  /// Sube un archivo de evidencia a la sección especificada.
  ///
  /// [folderId] es el UUID de annual_folder_id.
  /// [sectionId] es el UUID de la sección dentro de la carpeta anual.
  Future<EvidenceFileModel> uploadFile({
    required String folderId,
    required String sectionId,
    required String filePath,
    required String fileName,
    required String mimeType,
    String? notes,
    void Function(double)? onProgress,
  });

  /// Elimina un archivo de evidencia.
  ///
  /// Solo requiere [evidenceId] (UUID).
  Future<void> deleteFile({required String evidenceId});
}

/// Implementación de la fuente de datos remota de carpeta de evidencias.
///
/// Consume los endpoints del módulo AnnualFolders en el backend SACDIA.
/// Auth token es inyectado automáticamente por [AuthInterceptor].
class EvidenceFolderRemoteDataSourceImpl
    implements EvidenceFolderRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'EvidenceFolderDS';

  EvidenceFolderRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  // ── GET /club-sections/:sectionId/annual-folder ───────────────────────────

  @override
  Future<EvidenceFolderModel> getEvidenceFolder(
      String clubSectionId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubSections}/$clubSectionId/annual-folder',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        // El backend puede envolver en { data: {...} }
        final folderJson = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
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

  // ── POST /annual-folders/:folderId/submit ─────────────────────────────────

  @override
  Future<void> submitFolder(String folderId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.annualFolders}/$folderId/submit',
      );

      if (response.statusCode == 200 || response.statusCode == 201) return;

      throw ServerException(
        message: 'Error al enviar la carpeta a validación',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en submitFolder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /annual-folders/:folderId/sections/:sectionId/submit ────────────

  @override
  Future<void> submitSection({
    required String folderId,
    required String sectionId,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.annualFolders}/$folderId/sections/$sectionId/submit',
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

  // ── POST /annual-folders/:folderId/sections/:sectionId/evidences ──────────

  @override
  Future<EvidenceFileModel> uploadFile({
    required String folderId,
    required String sectionId,
    required String filePath,
    required String fileName,
    required String mimeType,
    String? notes,
    void Function(double)? onProgress,
  }) async {
    try {
      final formFields = <String, dynamic>{
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      };

      if (notes != null && notes.isNotEmpty) {
        formFields['notes'] = notes;
      }

      final formData = FormData.fromMap(formFields);

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.annualFolders}/$folderId/sections/$sectionId/evidences',
        data: formData,
        options: Options(
          headers: {
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

  // ── DELETE /annual-folders/evidences/:evidenceId ──────────────────────────

  @override
  Future<void> deleteFile({required String evidenceId}) async {
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
        message: 'Error al eliminar el archivo',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en deleteFile', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Error helper ──────────────────────────────────────────────────────────

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
