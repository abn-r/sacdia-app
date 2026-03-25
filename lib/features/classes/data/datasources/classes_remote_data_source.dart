import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/class_model.dart';
import '../models/class_module_model.dart';
import '../models/class_progress_model.dart';
import '../models/class_with_progress_model.dart';
import '../models/requirement_evidence_model.dart';

/// Interfaz para la fuente de datos remota de clases progresivas
abstract class ClassesRemoteDataSource {
  Future<List<ClassModel>> getClasses({int? clubTypeId});
  Future<ClassModel> getClassById(int classId);
  Future<List<ClassModuleModel>> getClassModules(int classId);
  Future<List<ClassModel>> getUserClasses(String userId);
  Future<ClassProgressModel> getUserClassProgress(String userId, int classId);
  Future<ClassProgressModel> updateUserClassProgress(
      String userId, int classId, Map<String, dynamic> progressData);

  // ── Inscripción en clases anteriores ─────────────────────────────────────

  /// Inscribe al usuario en una clase para el año eclesiástico dado.
  Future<void> enrollUser(String userId, int classId, int yearId);

  // ── Nuevas operaciones para flujo de evidencias ────────────────────────────

  /// Obtiene la clase con progreso detallado (modulos + requerimientos + evidencias).
  Future<ClassWithProgressModel> getClassWithProgress(
      String userId, int classId);

  /// Envia un requerimiento a validacion.
  Future<void> submitRequirement(
      String userId, int classId, int requirementId);

  /// Sube un archivo de evidencia a un requerimiento.
  Future<RequirementEvidenceModel> uploadRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String filePath,
    required String fileName,
    required String mimeType,
  });

  /// Elimina un archivo de evidencia de un requerimiento.
  Future<void> deleteRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String fileId,
  });
}

/// Implementacion de la fuente de datos remota de clases progresivas.
///
/// Utiliza Dio para llamadas REST al backend SACDIA.
/// Auth token se lee desde [FlutterSecureStorage].
class ClassesRemoteDataSourceImpl implements ClassesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'ClassesDS';

  ClassesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  Future<String> _getAuthToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) {
      throw AuthException(message: 'No hay sesion activa');
    }
    return token;
  }

  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

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
        return (data['message'] ?? e.message ?? 'Error de conexion').toString();
      }
    } catch (_) {}
    return e.message ?? 'Error de conexion';
  }

  // ── POST /users/:userId/classes/enroll ──────────────────────────────────────

  @override
  Future<void> enrollUser(String userId, int classId, int yearId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.post(
        '$_baseUrl/users/$userId/classes/enroll',
        data: {
          'class_id': classId,
          'ecclesiastical_year_id': yearId,
        },
        options: _authOptions(token),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
        message: 'Error al inscribir en la clase',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en enrollUser', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /classes ────────────────────────────────────────────────────────────

  @override
  Future<List<ClassModel>> getClasses({int? clubTypeId}) async {
    try {
      final token = await _getAuthToken();
      final queryParams = clubTypeId != null ? '?clubTypeId=$clubTypeId' : '';

      final response = await _dio.get(
        '$_baseUrl/classes$queryParams',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        // El endpoint GET /classes retorna un resultado paginado: { data: [...], meta: {...} }
        // Soportamos también respuesta plana (List) por retrocompatibilidad.
        final List<dynamic> items = body is Map
            ? (body['data'] as List<dynamic>? ?? [])
            : (body as List<dynamic>);
        return items
            .map((json) => ClassModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: 'Error al obtener clases', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getClasses', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /classes/:classId ───────────────────────────────────────────────────

  @override
  Future<ClassModel> getClassById(int classId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl/classes/$classId',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: 'Error al obtener clase', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getClassById', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /classes/:classId/modules ───────────────────────────────────────────

  @override
  Future<List<ClassModuleModel>> getClassModules(int classId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl/classes/$classId/modules',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) =>
                ClassModuleModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: 'Error al obtener modulos', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getClassModules', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /users/:userId/classes ──────────────────────────────────────────────

  @override
  Future<List<ClassModel>> getUserClasses(String userId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl/users/$userId/classes',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((enrollment) {
          final e = enrollment as Map<String, dynamic>;
          // El backend retorna inscripciones:
          // [{ enrollment_id, investiture_status, overall_progress, classes: {...} }]
          // Mezclamos los campos de enrollment sobre el JSON de clase para que
          // ClassModel.fromJson los reciba en un único mapa plano.
          final classJson =
              Map<String, dynamic>.from(
                  (e['classes'] as Map<String, dynamic>?) ?? e);
          if (e.containsKey('investiture_status')) {
            classJson['investiture_status'] = e['investiture_status'];
          }
          if (e.containsKey('overall_progress')) {
            classJson['overall_progress'] = e['overall_progress'];
          }
          return ClassModel.fromJson(classJson);
        }).toList();
      }

      throw ServerException(
          message: 'Error al obtener clases del usuario',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getUserClasses', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /users/:userId/classes/:classId/progress ────────────────────────────

  @override
  Future<ClassProgressModel> getUserClassProgress(
      String userId, int classId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl/users/$userId/classes/$classId/progress',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassProgressModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: 'Error al obtener progreso de clase',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getUserClassProgress', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── PATCH /users/:userId/classes/:classId/progress ──────────────────────────

  @override
  Future<ClassProgressModel> updateUserClassProgress(
    String userId,
    int classId,
    Map<String, dynamic> progressData,
  ) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.patch(
        '$_baseUrl/users/$userId/classes/$classId/progress',
        data: progressData,
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassProgressModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: 'Error al actualizar progreso de clase',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en updateUserClassProgress', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /users/:userId/classes/:classId/progress (detallado) ───────────────
  //
  // El endpoint GET /users/:userId/classes/:classId/progress devuelve el
  // progreso con modulos y secciones. El backend puede variar; construimos
  // la respuesta combinando clase + modulos + progreso por seccion.
  //
  // Si el backend no retorna el detalle completo en un solo endpoint,
  // combinamos las llamadas necesarias.

  @override
  Future<ClassWithProgressModel> getClassWithProgress(
      String userId, int classId) async {
    try {
      final token = await _getAuthToken();

      // Intentar obtener progreso detallado en un solo endpoint
      final response = await _dio.get(
        '$_baseUrl/users/$userId/classes/$classId/progress',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;

        // Si el backend retorna los modulos embebidos, usar directamente
        if (body.containsKey('modules')) {
          return ClassWithProgressModel.fromJson(body);
        }

        // Si no, obtener la clase y los modulos por separado y combinar
        final classResponse = await _dio.get(
          '$_baseUrl/classes/$classId',
          options: _authOptions(token),
        );

        final modulesResponse = await _dio.get(
          '$_baseUrl/classes/$classId/modules',
          options: _authOptions(token),
        );

        if (classResponse.statusCode == 200 &&
            modulesResponse.statusCode == 200) {
          final classJson = classResponse.data as Map<String, dynamic>;
          final modulesJson =
              modulesResponse.data as List<dynamic>;

          // Construir JSON combinado
          final combined = {
            ...classJson,
            'modules': modulesJson,
          };

          return ClassWithProgressModel.fromJson(combined);
        }
      }

      throw ServerException(
          message: 'Error al obtener clase con progreso',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getClassWithProgress', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /users/:userId/classes/:classId/sections/:sectionId/submit ─────────

  @override
  Future<void> submitRequirement(
      String userId, int classId, int requirementId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.post(
        '$_baseUrl/users/$userId/classes/$classId/sections/$requirementId/submit',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
          message: 'Error al enviar el requerimiento a validacion',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en submitRequirement', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /users/:userId/classes/:classId/sections/:sectionId/files ──────────

  @override
  Future<RequirementEvidenceModel> uploadRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String filePath,
    required String fileName,
    required String mimeType,
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
        '$_baseUrl/users/$userId/classes/$classId/sections/$requirementId/files',
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
            AppLogger.d(
              'Upload progress: ${(sent / total * 100).toStringAsFixed(1)}%',
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
        return RequirementEvidenceModel.fromJson(fileJson);
      }

      throw ServerException(
        message: 'Error al subir el archivo de evidencia',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en uploadRequirementFile', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /users/:userId/classes/:classId/sections/:sectionId/files/:fileId

  @override
  Future<void> deleteRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String fileId,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.delete(
        '$_baseUrl/users/$userId/classes/$classId/sections/$requirementId/files/$fileId',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
        message: 'Error al eliminar el archivo de evidencia',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en deleteRequirementFile', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
