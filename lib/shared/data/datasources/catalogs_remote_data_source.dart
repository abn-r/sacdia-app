import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/catalogs/catalogs.dart';

/// Interfaz para la fuente de datos remota de catálogos del sistema
abstract class CatalogsRemoteDataSource {
  Future<List<ClubTypeModel>> getClubTypes({CancelToken? cancelToken});
  Future<List<ActivityTypeModel>> getActivityTypes({CancelToken? cancelToken});
  Future<List<DistrictModel>> getDistricts({int? localFieldId, CancelToken? cancelToken});
  Future<List<ChurchModel>> getChurches({int? districtId, CancelToken? cancelToken});
  Future<List<EcclesiasticalYearModel>> getEcclesiasticalYears({bool? active, CancelToken? cancelToken});
  Future<EcclesiasticalYearModel?> getCurrentEcclesiasticalYear({CancelToken? cancelToken});
}

/// Implementación de la fuente de datos remota de catálogos
class CatalogsRemoteDataSourceImpl implements CatalogsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'CatalogsDS';

  CatalogsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<List<ClubTypeModel>> getClubTypes({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/club-types',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => ClubTypeModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: tr('catalogs.errors.get_club_types'));
    } catch (e) {
      AppLogger.e('Error en getClubTypes', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
          message:
              e.response?.data?['message'] ?? e.message ?? tr('common.error_network'),
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ActivityTypeModel>> getActivityTypes({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/activity-types',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map(
              (json) => ActivityTypeModel.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      throw ServerException(message: tr('catalogs.errors.get_activity_types'));
    } catch (e) {
      AppLogger.e('Error en getActivityTypes', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
          message:
              e.response?.data?['message'] ?? e.message ?? tr('common.error_network'),
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<DistrictModel>> getDistricts({int? localFieldId, CancelToken? cancelToken}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (localFieldId != null) queryParams['localFieldId'] = localFieldId;

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/districts',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => DistrictModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: tr('catalogs.errors.get_districts'));
    } catch (e) {
      AppLogger.e('Error en getDistricts', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
          message:
              e.response?.data?['message'] ?? e.message ?? tr('common.error_network'),
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ChurchModel>> getChurches({int? districtId, CancelToken? cancelToken}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (districtId != null) queryParams['districtId'] = districtId;

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/churches',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => ChurchModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: tr('catalogs.errors.get_churches'));
    } catch (e) {
      AppLogger.e('Error en getChurches', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
          message:
              e.response?.data?['message'] ?? e.message ?? tr('common.error_network'),
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<EcclesiasticalYearModel>> getEcclesiasticalYears(
      {bool? active, CancelToken? cancelToken}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (active != null) queryParams['active'] = active;

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/ecclesiastical-years',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) =>
                EcclesiasticalYearModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: tr('catalogs.errors.get_ecclesiastical_years'));
    } catch (e) {
      AppLogger.e('Error en getEcclesiasticalYears', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
          message:
              e.response?.data?['message'] ?? e.message ?? tr('common.error_network'),
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<EcclesiasticalYearModel?> getCurrentEcclesiasticalYear({CancelToken? cancelToken}) async {
    try {
      final years = await getEcclesiasticalYears(active: true, cancelToken: cancelToken);
      return years.isNotEmpty ? years.first : null;
    } catch (e) {
      AppLogger.e('Error en getCurrentEcclesiasticalYear', tag: _tag, error: e);
      rethrow;
    }
  }
}
