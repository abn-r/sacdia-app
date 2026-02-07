import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/user_detail_model.dart';

/// Interfaz para la fuente de datos remota del perfil
abstract class ProfileRemoteDataSource {
  /// Obtiene el perfil del usuario
  Future<UserDetailModel> getUserProfile(String userId);

  /// Actualiza el perfil del usuario
  Future<UserDetailModel> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  );

  /// Actualiza la foto de perfil del usuario
  Future<String> updateProfilePicture(String userId, String filePath);
}

/// Implementación de la fuente de datos remota del perfil
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  ProfileRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  /// Obtiene el token de autenticación
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

      // Llamar al endpoint /auth/me para obtener el perfil completo
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

      return UserDetailModel.fromJson(response.data);
    } on DioException catch (e) {
      log('Error Dio al obtener perfil: ${e.message}');
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al obtener perfil',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      log('Error al obtener perfil: $e');
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

      // Llamar al endpoint PATCH /users/:userId
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
      log('Error Dio al actualizar perfil: ${e.message}');
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al actualizar perfil',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      log('Error al actualizar perfil: $e');
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

      // Crear FormData con la imagen
      final file = File(filePath);
      final fileName = file.path.split('/').last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      // Llamar al endpoint POST /users/:userId/profile-picture
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

      // Retornar la URL de la imagen
      return response.data['url'] as String? ??
          response.data['avatar'] as String? ??
          '';
    } on DioException catch (e) {
      log('Error Dio al actualizar foto: ${e.message}');
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al actualizar foto',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      log('Error al actualizar foto: $e');
      throw ServerException(message: e.toString());
    }
  }
}
