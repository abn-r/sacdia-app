import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/completion_status_model.dart';

/// Interfaz para la fuente de datos remota de post-registro
abstract class PostRegistrationRemoteDataSource {
  Future<CompletionStatusModel> getCompletionStatus();
  Future<String> uploadProfilePicture({required String userId, required String filePath});
  Future<void> deleteProfilePicture({required String userId});
  Future<bool> getPhotoStatus({required String userId});
  Future<void> completeStep1(String userId);
}

/// Implementación de la fuente de datos remota de post-registro
class PostRegistrationRemoteDataSourceImpl
    implements PostRegistrationRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'PostRegistrationDS';

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

      final String extension = filePath.contains('.')
          ? filePath.split('.').last.toLowerCase()
          : 'jpg';

      String mimeType = 'image/jpeg';
      if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          contentType: MediaType.parse(mimeType),
        ),
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
      AppLogger.e('Error al subir foto de perfil', tag: _tag, error: e);
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

  @override
  Future<void> completeStep1(String userId) async {
    try {
      final options = await _authOptions();
      final response = await _dio.post(
        '$_baseUrl/users/$userId/post-registration/step-1/complete',
        options: options,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
            message: 'Error al completar el paso 1 del post-registro');
      }
    } catch (e) {
      AppLogger.e('Error en completeStep1', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}
