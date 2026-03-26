import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/paginated_resources_model.dart';
import '../models/resource_category_model.dart';
import '../models/resource_model.dart';

/// Interfaz para la fuente de datos remota de recursos
abstract class ResourcesRemoteDataSource {
  Future<PaginatedResourcesModel> getVisibleResources({
    int page = 1,
    int limit = 20,
    String? resourceType,
    int? categoryId,
    String? search,
  });

  Future<ResourceModel> getResource(String id);

  Future<String> getSignedUrl(String id);

  Future<List<ResourceCategoryModel>> getCategories();
}

/// Implementación de la fuente de datos remota de recursos
class ResourcesRemoteDataSourceImpl implements ResourcesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'ResourcesDS';

  ResourcesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  Future<String> _getAuthToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) {
      throw AuthException(message: 'No hay sesión activa');
    }
    return token;
  }

  @override
  Future<PaginatedResourcesModel> getVisibleResources({
    int page = 1,
    int limit = 20,
    String? resourceType,
    int? categoryId,
    String? search,
  }) async {
    try {
      final token = await _getAuthToken();

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (resourceType != null) queryParams['resource_type'] = resourceType;
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '$_baseUrl/resources/me',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return PaginatedResourcesModel.fromJson(response.data);
      }

      throw ServerException(
        message: 'Error al obtener recursos',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getVisibleResources', tag: _tag, error: e);
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
  Future<ResourceModel> getResource(String id) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl/resources/me/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResourceModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al obtener recurso',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getResource', tag: _tag, error: e);
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
  Future<String> getSignedUrl(String id) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl/resources/me/$id/signed-url',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return (data['signed_url'] ?? data['url']) as String;
        }
        return data as String;
      }

      throw ServerException(
        message: 'Error al obtener URL de descarga',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getSignedUrl', tag: _tag, error: e);
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
  Future<List<ResourceCategoryModel>> getCategories() async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl/resource-categories',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data;
        final List<dynamic> data =
            raw is Map ? (raw['data'] as List<dynamic>) : raw as List<dynamic>;
        return data
            .map((e) =>
                ResourceCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener categorías',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getCategories', tag: _tag, error: e);
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
