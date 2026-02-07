import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/honor_model.dart';
import '../models/honor_category_model.dart';
import '../models/user_honor_model.dart';

/// Interfaz para la fuente de datos remota de especialidades
abstract class HonorsRemoteDataSource {
  /// Obtiene todas las categorías de especialidades
  Future<List<HonorCategoryModel>> getHonorCategories();

  /// Obtiene especialidades filtradas
  Future<List<HonorModel>> getHonors({
    int? categoryId,
    int? clubTypeId,
    int? skillLevel,
  });

  /// Obtiene el detalle de una especialidad
  Future<HonorModel> getHonorById(int honorId);

  /// Obtiene las especialidades de un usuario
  Future<List<UserHonorModel>> getUserHonors(String userId);

  /// Obtiene estadísticas de especialidades de un usuario
  Future<Map<String, dynamic>> getUserHonorStats(String userId);

  /// Inscribe a un usuario en una especialidad
  Future<UserHonorModel> enrollUserInHonor(String userId, int honorId);

  /// Actualiza el estado de una especialidad de usuario
  Future<UserHonorModel> updateUserHonor(String userId, int honorId, Map<String, dynamic> data);

  /// Elimina la inscripción de un usuario en una especialidad
  Future<void> deleteUserHonor(String userId, int honorId);
}

/// Implementación de la fuente de datos remota de especialidades
class HonorsRemoteDataSourceImpl implements HonorsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  HonorsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  /// Obtiene el token de autenticación
  Future<String> _getAuthToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) {
      throw AuthException(message: 'No hay sesión activa');
    }
    return token;
  }

  @override
  Future<List<HonorCategoryModel>> getHonorCategories() async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/honors/categories',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((categoryJson) =>
                HonorCategoryModel.fromJson(categoryJson as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener categorías',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener categorías: $e');
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
  Future<List<HonorModel>> getHonors({
    int? categoryId,
    int? clubTypeId,
    int? skillLevel,
  }) async {
    try {
      final token = await _getAuthToken();

      final queryParams = <String>[];
      if (categoryId != null) queryParams.add('categoryId=$categoryId');
      if (clubTypeId != null) queryParams.add('clubTypeId=$clubTypeId');
      if (skillLevel != null) queryParams.add('skillLevel=$skillLevel');

      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final response = await _dio.get(
        '$_baseUrl/honors$queryString',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((honorJson) => HonorModel.fromJson(honorJson as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener especialidades',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener especialidades: $e');
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
  Future<HonorModel> getHonorById(int honorId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/honors/$honorId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return HonorModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al obtener especialidad',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener especialidad: $e');
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
  Future<List<UserHonorModel>> getUserHonors(String userId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/users/$userId/honors',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((userHonorJson) =>
                UserHonorModel.fromJson(userHonorJson as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener especialidades del usuario',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener especialidades del usuario: $e');
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
  Future<Map<String, dynamic>> getUserHonorStats(String userId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/users/$userId/honors/stats',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }

      throw ServerException(
        message: 'Error al obtener estadísticas',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener estadísticas: $e');
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
  Future<UserHonorModel> enrollUserInHonor(String userId, int honorId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.post(
        '$_baseUrl/users/$userId/honors/$honorId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return UserHonorModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al inscribir en especialidad',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al inscribir en especialidad: $e');
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
  Future<UserHonorModel> updateUserHonor(
    String userId,
    int honorId,
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.patch(
        '$_baseUrl/users/$userId/honors/$honorId',
        data: data,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return UserHonorModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al actualizar especialidad',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al actualizar especialidad: $e');
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
  Future<void> deleteUserHonor(String userId, int honorId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.delete(
        '$_baseUrl/users/$userId/honors/$honorId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException(
          message: 'Error al eliminar especialidad',
          code: response.statusCode,
        );
      }
    } catch (e) {
      log('Error al eliminar especialidad: $e');
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
