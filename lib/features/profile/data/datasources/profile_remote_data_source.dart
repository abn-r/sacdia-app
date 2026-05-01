import 'dart:io';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/user_detail_model.dart';

/// Interfaz para la fuente de datos remota del perfil
abstract class ProfileRemoteDataSource {
  Future<UserDetailModel> getUserProfile(String userId, {CancelToken? cancelToken});
  Future<UserDetailModel> updateUserProfile(String userId, Map<String, dynamic> data);
  Future<String> updateProfilePicture(String userId, String filePath);
}

/// Implementación de la fuente de datos remota del perfil
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'ProfileDS';

  ProfileRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<UserDetailModel> getUserProfile(String userId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.auth}/me',
        cancelToken: cancelToken,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr('profile.errors.get_profile'),
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
        message: e.response?.data?['message'] ?? tr('common.error_network'),
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
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.users}/$userId',
        data: data,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr('profile.errors.update_profile'),
          code: response.statusCode,
        );
      }

      return UserDetailModel.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Error al actualizar perfil', tag: _tag, error: e.message);
      throw ServerException(
        message: e.response?.data?['message'] ?? tr('common.error_network'),
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
      final file = File(filePath);
      final fileName = file.path.split('/').last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/profile-picture',
        data: formData,
        options: Options(headers: {
          'Content-Type': 'multipart/form-data',
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr('profile.errors.update_picture'),
          code: response.statusCode,
        );
      }

      return response.data['url'] as String? ??
          response.data['avatar'] as String? ??
          '';
    } on DioException catch (e) {
      AppLogger.e('Error al actualizar foto de perfil', tag: _tag, error: e.message);
      throw ServerException(
        message: e.response?.data?['message'] ?? tr('common.error_network'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado al actualizar foto', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }
}
