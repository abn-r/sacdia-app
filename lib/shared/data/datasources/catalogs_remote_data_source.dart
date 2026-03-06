import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/catalogs/catalogs.dart';

/// Interfaz para la fuente de datos remota de catálogos del sistema
abstract class CatalogsRemoteDataSource {
  Future<List<ClubTypeModel>> getClubTypes();
  Future<List<ActivityTypeModel>> getActivityTypes();
  Future<List<DistrictModel>> getDistricts({int? localFieldId});
  Future<List<ChurchModel>> getChurches({int? districtId});
  Future<List<RoleModel>> getRoles({int? clubTypeId});
  Future<List<EcclesiasticalYearModel>> getEcclesiasticalYears({bool? active});
  Future<EcclesiasticalYearModel?> getCurrentEcclesiasticalYear();
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
  Future<List<ClubTypeModel>> getClubTypes() async {
    try {
      final response = await _dio.get('$_baseUrl/catalogs/club-types');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => ClubTypeModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: 'Error al obtener tipos de club');
    } catch (e) {
      AppLogger.e('Error en getClubTypes', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message:
              e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ActivityTypeModel>> getActivityTypes() async {
    try {
      final response = await _dio.get('$_baseUrl/catalogs/activity-types');

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

      throw ServerException(message: 'Error al obtener tipos de actividad');
    } catch (e) {
      AppLogger.e('Error en getActivityTypes', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message:
              e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<DistrictModel>> getDistricts({int? localFieldId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (localFieldId != null) queryParams['localFieldId'] = localFieldId;

      final response = await _dio.get(
        '$_baseUrl/catalogs/districts',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => DistrictModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: 'Error al obtener distritos');
    } catch (e) {
      AppLogger.e('Error en getDistricts', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message:
              e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ChurchModel>> getChurches({int? districtId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (districtId != null) queryParams['districtId'] = districtId;

      final response = await _dio.get(
        '$_baseUrl/catalogs/churches',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => ChurchModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: 'Error al obtener iglesias');
    } catch (e) {
      AppLogger.e('Error en getChurches', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message:
              e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<RoleModel>> getRoles({int? clubTypeId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (clubTypeId != null) queryParams['clubTypeId'] = clubTypeId;

      final response = await _dio.get(
        '$_baseUrl/catalogs/roles',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => RoleModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: 'Error al obtener roles');
    } catch (e) {
      AppLogger.e('Error en getRoles', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message:
              e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<EcclesiasticalYearModel>> getEcclesiasticalYears(
      {bool? active}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (active != null) queryParams['active'] = active;

      final response = await _dio.get(
        '$_baseUrl/catalogs/ecclesiastical-years',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) =>
                EcclesiasticalYearModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: 'Error al obtener años eclesiásticos');
    } catch (e) {
      AppLogger.e('Error en getEcclesiasticalYears', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message:
              e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<EcclesiasticalYearModel?> getCurrentEcclesiasticalYear() async {
    try {
      final years = await getEcclesiasticalYears(active: true);
      return years.isNotEmpty ? years.first : null;
    } catch (e) {
      AppLogger.e('Error en getCurrentEcclesiasticalYear', tag: _tag, error: e);
      rethrow;
    }
  }
}
