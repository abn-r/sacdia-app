import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../models/catalogs/catalogs.dart';

/// Interfaz para la fuente de datos remota de catálogos del sistema
abstract class CatalogsRemoteDataSource {
  /// Obtiene los tipos de club (Aventureros, Conquistadores, Guías Mayores)
  Future<List<ClubTypeModel>> getClubTypes();

  /// Obtiene los distritos, opcionalmente filtrados por campo local
  Future<List<DistrictModel>> getDistricts({int? localFieldId});

  /// Obtiene las iglesias, opcionalmente filtradas por distrito
  Future<List<ChurchModel>> getChurches({int? districtId});

  /// Obtiene los roles de club, opcionalmente filtrados por tipo de club
  Future<List<RoleModel>> getRoles({int? clubTypeId});

  /// Obtiene los años eclesiásticos, opcionalmente filtrados por estado activo
  Future<List<EcclesiasticalYearModel>> getEcclesiasticalYears({bool? active});

  /// Obtiene el año eclesiástico activo actual
  Future<EcclesiasticalYearModel?> getCurrentEcclesiasticalYear();
}

/// Implementación de la fuente de datos remota de catálogos
class CatalogsRemoteDataSourceImpl implements CatalogsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  CatalogsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<List<ClubTypeModel>> getClubTypes() async {
    try {
      log('📚 [CatalogsDataSource] Obteniendo tipos de club');

      final response = await _dio.get('$_baseUrl/catalogs/club-types');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => ClubTypeModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: 'Error al obtener tipos de club');
    } catch (e) {
      log('❌ [CatalogsDataSource] Error en getClubTypes: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<DistrictModel>> getDistricts({int? localFieldId}) async {
    try {
      log('📚 [CatalogsDataSource] Obteniendo distritos${localFieldId != null ? ' para campo local $localFieldId' : ''}');

      final queryParams = <String, dynamic>{};
      if (localFieldId != null) {
        queryParams['localFieldId'] = localFieldId;
      }

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
      log('❌ [CatalogsDataSource] Error en getDistricts: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ChurchModel>> getChurches({int? districtId}) async {
    try {
      log('📚 [CatalogsDataSource] Obteniendo iglesias${districtId != null ? ' para distrito $districtId' : ''}');

      final queryParams = <String, dynamic>{};
      if (districtId != null) {
        queryParams['districtId'] = districtId;
      }

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
      log('❌ [CatalogsDataSource] Error en getChurches: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<RoleModel>> getRoles({int? clubTypeId}) async {
    try {
      log('📚 [CatalogsDataSource] Obteniendo roles${clubTypeId != null ? ' para tipo de club $clubTypeId' : ''}');

      final queryParams = <String, dynamic>{};
      if (clubTypeId != null) {
        queryParams['clubTypeId'] = clubTypeId;
      }

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
      log('❌ [CatalogsDataSource] Error en getRoles: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
        );
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<EcclesiasticalYearModel>> getEcclesiasticalYears({
    bool? active,
  }) async {
    try {
      log('📚 [CatalogsDataSource] Obteniendo años eclesiásticos${active != null ? ' (active: $active)' : ''}');

      final queryParams = <String, dynamic>{};
      if (active != null) {
        queryParams['active'] = active;
      }

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
      log('❌ [CatalogsDataSource] Error en getEcclesiasticalYears: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
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
      log('❌ [CatalogsDataSource] Error en getCurrentEcclesiasticalYear: $e');
      rethrow;
    }
  }
}
