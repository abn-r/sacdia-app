import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/usecases/register_user_honor.dart';
import '../models/honor_model.dart';
import '../models/honor_category_model.dart';
import '../models/honor_group_model.dart';
import '../models/honor_requirement_model.dart';
import '../models/requirement_evidence_model.dart';
import '../models/user_honor_requirement_progress_model.dart';
import '../models/user_honor_model.dart';

/// Interfaz para la fuente de datos remota de especialidades
abstract class HonorsRemoteDataSource {
  Future<List<HonorCategoryModel>> getHonorCategories({CancelToken? cancelToken});
  Future<List<HonorModel>> getHonors({int? categoryId, int? clubTypeId, int? skillLevel, CancelToken? cancelToken});
  Future<HonorModel> getHonorById(int honorId, {CancelToken? cancelToken});
  Future<List<UserHonorModel>> getUserHonors(String userId, {CancelToken? cancelToken});
  Future<Map<String, dynamic>> getUserHonorStats(String userId, {CancelToken? cancelToken});
  Future<UserHonorModel> enrollUserInHonor(String userId, int honorId);
  Future<UserHonorModel> updateUserHonor(String userId, int honorId, Map<String, dynamic> data);
  Future<void> deleteUserHonor(String userId, int honorId);
  Future<UserHonorModel> registerUserHonor(RegisterUserHonorParams params);
  Future<List<HonorGroupModel>> getHonorsGroupedByCategory({CancelToken? cancelToken});

  /// Obtiene los requisitos del catálogo de una especialidad.
  /// GET /honors/:honorId/requirements — público
  Future<List<HonorRequirementModel>> getHonorRequirements(int honorId, {CancelToken? cancelToken});

  /// Obtiene el progreso del usuario por requisito para una especialidad inscrita.
  /// GET /users/:userId/honors/:honorId/requirements/progress
  Future<List<UserHonorRequirementProgressModel>> getUserHonorProgress(String userId, int honorId, {CancelToken? cancelToken});

  /// Actualiza el progreso de un requisito individual.
  /// PATCH /honors/:honorId/progress/:requirementId
  Future<UserHonorRequirementProgressModel> updateRequirementProgress({
    required int honorId,
    required int requirementId,
    required bool completed,
    String? notes,
  });

  /// Actualiza el progreso de múltiples requisitos en una sola operación.
  /// PATCH /users/:userId/honors/:honorId/requirements/progress/batch
  Future<List<UserHonorRequirementProgressModel>> bulkUpdateRequirementProgress(
      String userId,
      int honorId,
      List<Map<String, dynamic>> updates);

  /// Sube un archivo de evidencia al honor del usuario.
  ///
  /// Llama a POST /users/:userId/honors/:userHonorId/files con el archivo
  /// como campo `images` en multipart/form-data.
  Future<void> uploadHonorFile({
    required String userId,
    required int honorId,
    required File file,
    required String fileName,
  });

  /// Sube un archivo de evidencia para un requisito específico de una especialidad.
  ///
  /// POST /users/:userId/honors/:honorId/requirements/:requirementId/evidence/upload
  /// Envía el archivo como multipart/form-data con el campo `file`.
  /// [mimeType] se pasa explícitamente para fijar el Content-Type del part.
  Future<RequirementEvidenceModel> uploadRequirementEvidence(
    String userId,
    int honorId,
    int requirementId,
    File file, {
    required String mimeType,
  });

  /// Agrega un enlace como evidencia de un requisito.
  ///
  /// POST /users/:userId/honors/:honorId/requirements/:requirementId/evidence/link
  /// Body JSON: { "url": url }
  Future<RequirementEvidenceModel> addRequirementEvidenceLink(
    String userId,
    int honorId,
    int requirementId,
    String url,
  );

  /// Obtiene todas las evidencias de un requisito de especialidad.
  ///
  /// GET /users/:userId/honors/:honorId/requirements/:requirementId/evidence
  Future<List<RequirementEvidenceModel>> getRequirementEvidences(
    String userId,
    int honorId,
    int requirementId, {
    CancelToken? cancelToken,
  });

  /// Elimina una evidencia de un requisito de especialidad.
  ///
  /// DELETE /users/:userId/honors/:honorId/requirements/:requirementId/evidence/:evidenceId
  Future<void> deleteRequirementEvidence(
    String userId,
    int honorId,
    int requirementId,
    int evidenceId,
  );
}

/// Implementación de la fuente de datos remota de especialidades
class HonorsRemoteDataSourceImpl implements HonorsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'HonorsDS';

  HonorsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<List<HonorCategoryModel>> getHonorCategories({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.honors}/categories',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => HonorCategoryModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: 'Error al obtener categorías', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getHonorCategories', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<HonorModel>> getHonors({int? categoryId, int? clubTypeId, int? skillLevel, CancelToken? cancelToken}) async {
    try {
      final baseParams = <String>['limit=100'];
      if (categoryId != null) baseParams.add('categoryId=$categoryId');
      if (clubTypeId != null) baseParams.add('clubTypeId=$clubTypeId');
      if (skillLevel != null) baseParams.add('skillLevel=$skillLevel');

      final allHonors = <HonorModel>[];
      int page = 1;
      bool hasNextPage = true;

      while (hasNextPage) {
        final queryString = '?${baseParams.join('&')}&page=$page';
        final response = await _dio.get(
          '$_baseUrl${ApiEndpoints.honors}$queryString',
          cancelToken: cancelToken,
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw ServerException(
            message: 'Error al obtener especialidades',
            code: response.statusCode,
          );
        }

        final raw = response.data;
        final List<dynamic> data;
        if (raw is Map) {
          data = raw['data'] as List<dynamic>;
          final meta = raw['meta'] as Map<String, dynamic>?;
          hasNextPage = meta?['hasNextPage'] as bool? ?? false;
        } else {
          data = raw as List<dynamic>;
          hasNextPage = false;
        }

        allHonors.addAll(
          data.map((json) => HonorModel.fromJson(json as Map<String, dynamic>)),
        );
        page++;
      }

      return allHonors;
    } catch (e) {
      AppLogger.e('Error en getHonors', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<HonorModel> getHonorById(int honorId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.honors}/$honorId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return HonorModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(message: 'Error al obtener especialidad', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getHonorById', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<UserHonorModel>> getUserHonors(String userId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => UserHonorModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: 'Error al obtener especialidades del usuario', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getUserHonors', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getUserHonorStats(String userId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors/stats',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }

      throw ServerException(message: 'Error al obtener estadísticas', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getUserHonorStats', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserHonorModel> enrollUserInHonor(String userId, int honorId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors/$honorId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return UserHonorModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(message: 'Error al inscribir en especialidad', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en enrollUserInHonor', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserHonorModel> updateUserHonor(String userId, int honorId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors/$honorId',
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return UserHonorModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(message: 'Error al actualizar especialidad', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en updateUserHonor', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteUserHonor(String userId, int honorId) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors/$honorId',
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException(message: 'Error al eliminar especialidad', code: response.statusCode);
      }
    } catch (e) {
      AppLogger.e('Error en deleteUserHonor', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserHonorModel> registerUserHonor(RegisterUserHonorParams params) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.users}/${params.userId}/honors',
        data: params.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return UserHonorModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al registrar especialidad',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en registerUserHonor', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<HonorGroupModel>> getHonorsGroupedByCategory({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.honors}/grouped-by-category',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => HonorGroupModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener especialidades agrupadas',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getHonorsGroupedByCategory', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<HonorRequirementModel>> getHonorRequirements(int honorId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.honors}/$honorId/requirements',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // API returns: { data: { honor_id, total_requirements, requirements: [...] } }
        final raw = response.data as Map<String, dynamic>;
        final data = raw['data'] as Map<String, dynamic>;
        final List<dynamic> requirements = data['requirements'] as List<dynamic>;
        return requirements
            .map((json) =>
                HonorRequirementModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener requisitos de la especialidad',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getHonorRequirements', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
            message: e.message ?? 'Error de conexión',
            code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<UserHonorRequirementProgressModel>> getUserHonorProgress(
      String userId, int honorId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId${ApiEndpoints.honors}/$honorId/requirements/progress',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data as Map<String, dynamic>;
        final data = raw['data'] as Map<String, dynamic>;
        final List<dynamic> items = data['requirements'] as List<dynamic>;
        return items
            .map((json) => UserHonorRequirementProgressModel.fromJson(
                json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener progreso de requisitos',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getUserHonorProgress', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
            message: e.message ?? 'Error de conexión',
            code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserHonorRequirementProgressModel> updateRequirementProgress({
    required int honorId,
    required int requirementId,
    required bool completed,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'completed': completed,
        if (notes != null) 'notes': notes,
      };
      // New API: PATCH /honors/:honorId/progress/:requirementId
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.honors}/$honorId/progress/$requirementId',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data as Map<String, dynamic>;
        final data = raw['data'] as Map<String, dynamic>;
        return UserHonorRequirementProgressModel.fromJson(data);
      }

      throw ServerException(
        message: 'Error al actualizar requisito',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en updateRequirementProgress', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
            message: e.message ?? 'Error de conexión',
            code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<UserHonorRequirementProgressModel>> bulkUpdateRequirementProgress(
      String userId,
      int honorId,
      List<Map<String, dynamic>> updates) async {
    try {
      // API: PATCH /users/:userId/honors/:honorId/requirements/progress/batch
      // Body: { requirements: [{ requirementId, completed, notes? }] }
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.users}/$userId${ApiEndpoints.honors}/$honorId/requirements/progress/batch',
        data: {'requirements': updates},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data as Map<String, dynamic>;
        final data = raw['data'] as Map<String, dynamic>;
        final List<dynamic> items = data['requirements'] as List<dynamic>;
        return items
            .map((json) => UserHonorRequirementProgressModel.fromJson(
                json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al actualizar progreso de requisitos',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en bulkUpdateRequirementProgress', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
            message: e.message ?? 'Error de conexión',
            code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> uploadHonorFile({
    required String userId,
    required int honorId,
    required File file,
    required String fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'images': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors/$honorId/files',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) return;

      throw ServerException(
        message: 'Error al subir evidencia',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en uploadHonorFile', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<RequirementEvidenceModel> uploadRequirementEvidence(
    String userId,
    int honorId,
    int requirementId,
    File file, {
    required String mimeType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
          contentType: MediaType.parse(mimeType),
        ),
      });

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors/$honorId/requirements/$requirementId/evidence/upload',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return RequirementEvidenceModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al subir evidencia de requisito',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en uploadRequirementEvidence', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<RequirementEvidenceModel> addRequirementEvidenceLink(
    String userId,
    int honorId,
    int requirementId,
    String url,
  ) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors/$honorId/requirements/$requirementId/evidence/link',
        data: {'url': url},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return RequirementEvidenceModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al agregar enlace de evidencia',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en addRequirementEvidenceLink', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<RequirementEvidenceModel>> getRequirementEvidences(
    String userId,
    int honorId,
    int requirementId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors/$honorId/requirements/$requirementId/evidence',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // API returns: { status: 'success', data: [...] }
        final raw = response.data as Map<String, dynamic>;
        final List<dynamic> data = raw['data'] as List<dynamic>;
        return data
            .map((json) =>
                RequirementEvidenceModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener evidencias del requisito',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getRequirementEvidences', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteRequirementEvidence(
    String userId,
    int honorId,
    int requirementId,
    int evidenceId,
  ) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors/$honorId/requirements/$requirementId/evidence/$evidenceId',
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException(
          message: 'Error al eliminar evidencia del requisito',
          code: response.statusCode,
        );
      }
    } catch (e) {
      AppLogger.e('Error en deleteRequirementEvidence', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}
