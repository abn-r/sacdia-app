import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/completion_status_model.dart';

/// Interfaz para la fuente de datos remota de post-registro
abstract class PostRegistrationRemoteDataSource {
  /// Obtiene el estado de completitud del post-registro
  Future<CompletionStatusModel> getCompletionStatus();

  /// Sube la foto de perfil
  Future<String> uploadProfilePicture({
    required String userId,
    required String filePath,
  });

  /// Elimina la foto de perfil
  Future<void> deleteProfilePicture({required String userId});

  /// Obtiene el estado de la foto
  Future<bool> getPhotoStatus({required String userId});
}

/// Implementación de la fuente de datos remota de post-registro
class PostRegistrationRemoteDataSourceImpl
    implements PostRegistrationRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  PostRegistrationRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  Future<Options> _authOptions() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) {
      throw AuthException(message: 'No hay sesión activa');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<CompletionStatusModel> getCompletionStatus() async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '$_baseUrl/auth/profile/completion-status',
        options: options,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CompletionStatusModel.fromJson(response.data);
      }

      throw ServerException(message: 'Error al obtener estado de completitud');
    } catch (e) {
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String> uploadProfilePicture({
    required String userId,
    required String filePath,
  }) async {
    try {
      final options = await _authOptions();
      options.contentType = 'multipart/form-data';

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post(
        '$_baseUrl/users/$userId/profile-picture',
        data: formData,
        options: options,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['url'] as String? ?? '';
      }

      throw ServerException(message: 'Error al subir foto de perfil');
    } catch (e) {
      log('Error al subir foto de perfil: $e');
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteProfilePicture({required String userId}) async {
    try {
      final options = await _authOptions();
      final response = await _dio.delete(
        '$_baseUrl/users/$userId/profile-picture',
        options: options,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException(message: 'Error al eliminar foto de perfil');
      }
    } catch (e) {
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<bool> getPhotoStatus({required String userId}) async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '$_baseUrl/users/$userId/post-registration/photo-status',
        options: options,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['has_photo'] as bool? ?? false;
      }

      return false;
    } catch (e) {
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}
