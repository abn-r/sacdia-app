import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http_parser/http_parser.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/completion_status_model.dart';

/// Interfaz para la fuente de datos remota de post-registro
abstract class PostRegistrationRemoteDataSource {
  Future<CompletionStatusModel> getCompletionStatus({CancelToken? cancelToken});
  Future<String> uploadProfilePicture({required String userId, required String filePath});
  Future<void> deleteProfilePicture({required String userId});
  Future<bool> getPhotoStatus({required String userId, CancelToken? cancelToken});
  Future<void> completeStep1(String userId);
}

/// Implementación de la fuente de datos remota de post-registro
class PostRegistrationRemoteDataSourceImpl
    implements PostRegistrationRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'PostRegistrationDS';

  PostRegistrationRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<CompletionStatusModel> getCompletionStatus({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.auth}/profile/completion-status',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CompletionStatusModel.fromJson(response.data);
      }

      throw ServerException(message: tr('post_registration.errors.fetch_completion_status'));
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? tr('common.error_network'));
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
        '$_baseUrl${ApiEndpoints.users}/$userId/profile-picture',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['url'] as String? ?? '';
      }

      throw ServerException(message: tr('post_registration.errors.upload_profile_photo'));
    } catch (e) {
      AppLogger.e('Error al subir foto de perfil', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(message: e.message ?? tr('common.error_network'));
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteProfilePicture({required String userId}) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.users}/$userId/profile-picture',
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException(message: tr('post_registration.errors.delete_profile_photo'));
      }
    } catch (e) {
      if (e is DioException) {
        throw ServerException(message: e.message ?? tr('common.error_network'));
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<bool> getPhotoStatus({
    required String userId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/post-registration/photo-status',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['has_photo'] as bool? ?? false;
      }

      return false;
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? tr('common.error_network'));
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> completeStep1(String userId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/post-registration/step-1/complete',
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
            message: tr('post_registration.errors.complete_step_1'));
      }
    } catch (e) {
      AppLogger.e('Error en completeStep1', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(message: e.message ?? tr('common.error_network'));
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}
