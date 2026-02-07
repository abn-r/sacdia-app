import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/country_model.dart';
import '../models/union_model.dart';
import '../models/local_field_model.dart';
import '../models/club_model.dart';
import '../models/club_instance_model.dart';
import '../models/class_model.dart';

/// Interfaz para la fuente de datos remota de selección de club
abstract class ClubSelectionRemoteDataSource {
  /// Obtiene la lista de países
  Future<List<CountryModel>> getCountries();

  /// Obtiene las uniones de un país
  Future<List<UnionModel>> getUnionsByCountry(int countryId);

  /// Obtiene los campos locales de una unión
  Future<List<LocalFieldModel>> getLocalFieldsByUnion(int unionId);

  /// Obtiene los clubes de un campo local
  Future<List<ClubModel>> getClubsByLocalField(int localFieldId);

  /// Obtiene las instancias (tipos) de un club
  Future<List<ClubInstanceModel>> getClubInstances(int clubId);

  /// Obtiene las clases progresivas de un tipo de club
  Future<List<ClassModel>> getClassesByClubType(int clubTypeId);

  /// Completa el paso 3 del post-registro
  Future<void> completeStep3({
    required String userId,
    required int countryId,
    required int unionId,
    required int localFieldId,
    required int clubInstanceId,
    required int classId,
  });
}

/// Implementación de la fuente de datos remota de selección de club
class ClubSelectionRemoteDataSourceImpl
    implements ClubSelectionRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  ClubSelectionRemoteDataSourceImpl({
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
  Future<List<CountryModel>> getCountries() async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '$_baseUrl/catalogs/countries',
        options: options,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => CountryModel.fromJson(json)).toList();
      }

      throw ServerException(message: 'Error al obtener países');
    } catch (e) {
      log('Error al obtener países: $e');
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<UnionModel>> getUnionsByCountry(int countryId) async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '$_baseUrl/catalogs/unions?countryId=$countryId',
        options: options,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => UnionModel.fromJson(json)).toList();
      }

      throw ServerException(message: 'Error al obtener uniones');
    } catch (e) {
      log('Error al obtener uniones: $e');
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<LocalFieldModel>> getLocalFieldsByUnion(int unionId) async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '$_baseUrl/catalogs/local-fields?unionId=$unionId',
        options: options,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => LocalFieldModel.fromJson(json)).toList();
      }

      throw ServerException(message: 'Error al obtener campos locales');
    } catch (e) {
      log('Error al obtener campos locales: $e');
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ClubModel>> getClubsByLocalField(int localFieldId) async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '$_baseUrl/catalogs/local-fields/$localFieldId/clubs',
        options: options,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => ClubModel.fromJson(json)).toList();
      }

      throw ServerException(message: 'Error al obtener clubes');
    } catch (e) {
      log('Error al obtener clubes: $e');
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ClubInstanceModel>> getClubInstances(int clubId) async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '$_baseUrl/clubs/$clubId/instances',
        options: options,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => ClubInstanceModel.fromJson(json)).toList();
      }

      throw ServerException(message: 'Error al obtener tipos de club');
    } catch (e) {
      log('Error al obtener tipos de club: $e');
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ClassModel>> getClassesByClubType(int clubTypeId) async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '$_baseUrl/catalogs/classes?clubTypeId=$clubTypeId',
        options: options,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => ClassModel.fromJson(json)).toList();
      }

      throw ServerException(message: 'Error al obtener clases');
    } catch (e) {
      log('Error al obtener clases: $e');
      if (e is DioException) {
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
    required int clubInstanceId,
    required int classId,
  }) async {
    try {
      final options = await _authOptions();
      final response = await _dio.post(
        '$_baseUrl/users/$userId/post-registration/complete-step-3',
        data: {
          'country_id': countryId,
          'union_id': unionId,
          'local_field_id': localFieldId,
          'club_instance_id': clubInstanceId,
          'class_id': classId,
        },
        options: options,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
            message: 'Error al completar el paso 3 del post-registro');
      }
    } catch (e) {
      log('Error al completar paso 3: $e');
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión');
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}
