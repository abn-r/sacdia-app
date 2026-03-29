import 'dart:io';

import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/usecases/register_user_honor.dart';
import '../models/honor_model.dart';
import '../models/honor_category_model.dart';
import '../models/honor_group_model.dart';
import '../models/honor_requirement_model.dart';
import '../models/user_honor_requirement_progress_model.dart';
import '../models/user_honor_model.dart';

/// Interfaz para la fuente de datos remota de especialidades
abstract class HonorsRemoteDataSource {
  Future<List<HonorCategoryModel>> getHonorCategories();
  Future<List<HonorModel>> getHonors({int? categoryId, int? clubTypeId, int? skillLevel});
  Future<HonorModel> getHonorById(int honorId);
  Future<List<UserHonorModel>> getUserHonors(String userId);
  Future<Map<String, dynamic>> getUserHonorStats(String userId);
  Future<UserHonorModel> enrollUserInHonor(String userId, int honorId);
  Future<UserHonorModel> updateUserHonor(String userId, int honorId, Map<String, dynamic> data);
  Future<void> deleteUserHonor(String userId, int honorId);
  Future<UserHonorModel> registerUserHonor(RegisterUserHonorParams params);
  Future<List<HonorGroupModel>> getHonorsGroupedByCategory();

  /// Obtiene los requisitos del catálogo de una especialidad.
  /// GET /honors/:honorId/requirements — público
  Future<List<HonorRequirementModel>> getHonorRequirements(int honorId);

  /// Obtiene el progreso del usuario por requisito para una especialidad inscrita.
  /// GET /honors/:honorId/progress — userId deriva del JWT
  Future<List<UserHonorRequirementProgressModel>> getUserHonorProgress(int honorId);

  /// Actualiza el progreso de un requisito individual.
  /// PATCH /honors/:honorId/progress/:requirementId
  Future<UserHonorRequirementProgressModel> updateRequirementProgress({
    required int honorId,
    required int requirementId,
    required bool completed,
    String? notes,
  });

  /// Actualiza el progreso de múltiples requisitos en una sola operación.
  /// PATCH /honors/:honorId/progress/bulk
  Future<List<UserHonorRequirementProgressModel>> bulkUpdateRequirementProgress(
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
  Future<List<HonorCategoryModel>> getHonorCategories() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.honors}/categories',
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
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<HonorModel>> getHonors({int? categoryId, int? clubTypeId, int? skillLevel}) async {
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
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<HonorModel> getHonorById(int honorId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.honors}/$honorId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return HonorModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(message: 'Error al obtener especialidad', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getHonorById', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<UserHonorModel>> getUserHonors(String userId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors',
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
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getUserHonorStats(String userId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/honors/stats',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }

      throw ServerException(message: 'Error al obtener estadísticas', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getUserHonorStats', tag: _tag, error: e);
      if (e is DioException) {
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
  Future<List<HonorGroupModel>> getHonorsGroupedByCategory() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.honors}/grouped-by-category',
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
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<HonorRequirementModel>> getHonorRequirements(int honorId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.honors}/$honorId/requirements',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // New API: { data: [...] } — flat array directly under 'data'
        final raw = response.data as Map<String, dynamic>;
        final List<dynamic> requirements = raw['data'] as List<dynamic>;
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
      int honorId) async {
    try {
      // New API: GET /honors/:honorId/progress — userId derived from JWT
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.honors}/$honorId/progress',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data as Map<String, dynamic>;
        final List<dynamic> items = raw['data'] as List<dynamic>;
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
      int honorId,
      List<Map<String, dynamic>> updates) async {
    try {
      // New API: PATCH /honors/:honorId/progress/bulk
      // Body: { items: [{ requirementId, completed, notes? }] }
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.honors}/$honorId/progress/bulk',
        data: {'items': updates},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data as Map<String, dynamic>;
        final List<dynamic> items = raw['data'] as List<dynamic>;
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
}
