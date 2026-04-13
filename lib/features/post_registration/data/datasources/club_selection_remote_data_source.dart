import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/country_model.dart';
import '../models/union_model.dart';
import '../models/local_field_model.dart';
import '../models/club_model.dart';
import '../models/club_section_model.dart';
import '../models/class_model.dart';

/// Interfaz para la fuente de datos remota de selección de club
abstract class ClubSelectionRemoteDataSource {
  Future<List<CountryModel>> getCountries({CancelToken? cancelToken});
  Future<List<UnionModel>> getUnionsByCountry(int countryId, {CancelToken? cancelToken});
  Future<List<LocalFieldModel>> getLocalFieldsByUnion(int unionId, {CancelToken? cancelToken});
  Future<List<ClubModel>> getClubsByLocalField(int localFieldId, {CancelToken? cancelToken});
  Future<List<ClubSectionModel>> getClubSections(int clubId, {CancelToken? cancelToken});
  Future<List<ClassModel>> getClassesByClubType(int clubTypeId, {CancelToken? cancelToken});
  Future<void> completeStep3({
    required String userId,
    required int countryId,
    required int unionId,
    required int localFieldId,
    required int clubSectionId,
    required int classId,
  });
}

/// Implementación de la fuente de datos remota de selección de club
class ClubSelectionRemoteDataSourceImpl
    implements ClubSelectionRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'ClubSelectionDS';

  ClubSelectionRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<List<CountryModel>> getCountries({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/countries',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => CountryModel.fromJson(json)).toList();
      }

      throw ServerException(message: 'Error al obtener países');
    } catch (e) {
      AppLogger.e('Error en getCountries', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<UnionModel>> getUnionsByCountry(
    int countryId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/unions?countryId=$countryId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => UnionModel.fromJson(json)).toList();
      }

      throw ServerException(message: 'Error al obtener uniones');
    } catch (e) {
      AppLogger.e('Error en getUnionsByCountry', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<LocalFieldModel>> getLocalFieldsByUnion(
    int unionId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/local-fields?unionId=$unionId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => LocalFieldModel.fromJson(json)).toList();
      }

      throw ServerException(message: 'Error al obtener campos locales');
    } catch (e) {
      AppLogger.e('Error en getLocalFieldsByUnion', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ClubModel>> getClubsByLocalField(
    int localFieldId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}',
        queryParameters: {'localFieldId': localFieldId},
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.data as Map<String, dynamic>;
        final List<dynamic> data = responseBody['data'] as List<dynamic>;
        return data.map((json) => ClubModel.fromJson(json)).toList();
      }

      throw ServerException(message: 'Error al obtener clubes');
    } catch (e) {
      AppLogger.e('Error en getClubsByLocalField', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ClubSectionModel>> getClubSections(
    int clubId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic responseData = response.data;
        final List<dynamic> items;

        if (responseData is List) {
          items = responseData;
        } else if (responseData is Map<String, dynamic>) {
          items = responseData['data'] as List<dynamic>? ?? [];
        } else {
          items = [];
        }

        return items
            .map((json) =>
                ClubSectionModel.fromJson(json as Map<String, dynamic>))
            .where((section) => section.id > 0)
            .toList();
      }

      throw ServerException(message: 'Error al obtener secciones de club');
    } catch (e) {
      AppLogger.e('Error en getClubSections', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ClassModel>> getClassesByClubType(
    int clubTypeId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.classes}',
        queryParameters: {'clubTypeId': clubTypeId},
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.data as Map<String, dynamic>;
        final List<dynamic> data = responseBody['data'] as List<dynamic>;
        return data.map((json) => ClassModel.fromJson(json)).toList();
      }

      throw ServerException(message: 'Error al obtener clases');
    } catch (e) {
      AppLogger.e('Error en getClassesByClubType', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> completeStep3({
    required String userId,
    required int countryId,
    required int unionId,
    required int localFieldId,
    required int clubSectionId,
    required int classId,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/post-registration/step-3/complete',
        data: {
          'country_id': countryId,
          'union_id': unionId,
          'local_field_id': localFieldId,
          'club_section_id': clubSectionId,
          'class_id': classId,
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
            message: 'Error al completar el paso 3 del post-registro');
      }
    } catch (e) {
      AppLogger.e('Error en completeStep3', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}
