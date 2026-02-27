import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/user_detail_model.dart';

/// Interfaz para la fuente de datos remota del perfil
abstract class ProfileRemoteDataSource {
  Future<UserDetailModel> getUserProfile(String userId);
  Future<UserDetailModel> updateUserProfile(String userId, Map<String, dynamic> data);
  Future<String> updateProfilePicture(String userId, String filePath);
}

/// Implementación de la fuente de datos remota del perfil
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'ProfileDS';

  ProfileRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  @override
  Future<UserDetailModel> getUserProfile(String userId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw AuthException(message: 'No hay sesión activa');
      }

      final response = await _dio.get(
        '$_baseUrl/auth/me',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Error al obtener perfil del usuario',
          code: response.statusCode,
        );
      }

      // API wraps response: { "status": "success", "data": { ... } }
      final raw = response.data;
      final json = (raw is Map && raw.containsKey('data'))
          ? raw['data'] as Map<String, dynamic>
          : raw as Map<String, dynamic>;
      return UserDetailModel.fromJson(json);
    } on DioException catch (e) {
      AppLogger.e('Error al obtener perfil', tag: _tag, error: e.message);
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al obtener perfil',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado al obtener perfil', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserDetailModel> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw AuthException(message: 'No hay sesión activa');
      }

      final response = await _dio.patch(
        '$_baseUrl/users/$userId',
        data: data,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Error al actualizar perfil',
          code: response.statusCode,
        );
      }

      return UserDetailModel.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Error al actualizar perfil', tag: _tag, error: e.message);
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al actualizar perfil',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado al actualizar perfil', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String> updateProfilePicture(String userId, String filePath) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw AuthException(message: 'No hay sesión activa');
      }

      final file = File(filePath);
      final fileName = file.path.split('/').last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '$_baseUrl/users/$userId/profile-picture',
        data: formData,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Error al actualizar foto de perfil',
          code: response.statusCode,
        );
      }

      return response.data['url'] as String? ??
          response.data['avatar'] as String? ??
          '';
    } on DioException catch (e) {
      AppLogger.e('Error al actualizar foto de perfil', tag: _tag, error: e.message);
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al actualizar foto',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado al actualizar foto', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }
}
