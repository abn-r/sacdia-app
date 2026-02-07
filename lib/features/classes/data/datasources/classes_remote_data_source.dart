import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/class_model.dart';
import '../models/class_module_model.dart';
import '../models/class_progress_model.dart';

/// Interfaz para la fuente de datos remota de clases progresivas
abstract class ClassesRemoteDataSource {
  /// Obtiene todas las clases progresivas
  Future<List<ClassModel>> getClasses({int? clubTypeId});

  /// Obtiene el detalle de una clase específica
  Future<ClassModel> getClassById(int classId);

  /// Obtiene los módulos de una clase específica
  Future<List<ClassModuleModel>> getClassModules(int classId);

  /// Obtiene las clases de un usuario
  Future<List<ClassModel>> getUserClasses(String userId);

  /// Obtiene el progreso de una clase de un usuario
  Future<ClassProgressModel> getUserClassProgress(String userId, int classId);

  /// Actualiza el progreso de una clase de un usuario
  Future<ClassProgressModel> updateUserClassProgress(
    String userId,
    int classId,
    Map<String, dynamic> progressData,
  );
}

/// Implementación de la fuente de datos remota de clases progresivas
class ClassesRemoteDataSourceImpl implements ClassesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  ClassesRemoteDataSourceImpl({
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
  Future<List<ClassModel>> getClasses({int? clubTypeId}) async {
    try {
      final token = await _getAuthToken();

      final queryParams = clubTypeId != null ? '?clubTypeId=$clubTypeId' : '';

      final response = await _dio.get(
        '$_baseUrl/classes$queryParams',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((classJson) => ClassModel.fromJson(classJson as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener clases',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener clases: $e');
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
  Future<ClassModel> getClassById(int classId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/classes/$classId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al obtener clase',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener clase: $e');
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
  Future<List<ClassModuleModel>> getClassModules(int classId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/classes/$classId/modules',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((moduleJson) =>
                ClassModuleModel.fromJson(moduleJson as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener módulos',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener módulos: $e');
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
  Future<List<ClassModel>> getUserClasses(String userId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/users/$userId/classes',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((classJson) => ClassModel.fromJson(classJson as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener clases del usuario',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener clases del usuario: $e');
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
  Future<ClassProgressModel> getUserClassProgress(String userId, int classId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/users/$userId/classes/$classId/progress',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassProgressModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al obtener progreso de clase',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener progreso de clase: $e');
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
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassProgressModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al actualizar progreso de clase',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al actualizar progreso de clase: $e');
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
