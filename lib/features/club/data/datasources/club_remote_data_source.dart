import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/club_info_model.dart';

/// Interfaz para la fuente de datos remota del módulo de club.
abstract class ClubRemoteDataSource {
  /// Obtiene el club contenedor.
  Future<ClubInfoModel> getClub(String clubId);

  /// Obtiene la instancia de club por tipo e ID.
  Future<ClubInstanceModel> getClubInstance({
    required String clubId,
    required String instanceType,
    required int instanceId,
  });

  /// Actualiza una instancia de club (PATCH).
  Future<ClubInstanceModel> updateClubInstance({
    required String clubId,
    required String instanceType,
    required int instanceId,
    Map<String, dynamic>? data,
  });
}

/// Implementación de [ClubRemoteDataSource] usando Dio.
class ClubRemoteDataSourceImpl implements ClubRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'ClubDS';

  ClubRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  // ── Auth helpers ─────────────────────────────────────────────────────────

  Future<String> _getAuthToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) {
      throw AuthException(message: 'No hay sesión activa');
    }
    return token;
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
      };

  // ── Helpers de respuesta ─────────────────────────────────────────────────

  /// Desenvuelve el body { status, data: { ... } } o devuelve el mapa tal cual.
  Map<String, dynamic> _unwrapMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data') && body['data'] is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>;
      }
      return body;
    }
    return {};
  }

  // ── Endpoints ────────────────────────────────────────────────────────────

  @override
  Future<ClubInfoModel> getClub(String clubId) async {
    try {
      AppLogger.i('Obteniendo club: $clubId', tag: _tag);
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/clubs/$clubId',
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = _unwrapMap(response.data);
        return ClubInfoModel.fromJson(json);
      }

      throw ServerException(
        message: 'Error al obtener club',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en getClub', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? 'Error de red',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getClub', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ClubInstanceModel> getClubInstance({
    required String clubId,
    required String instanceType,
    required int instanceId,
  }) async {
    try {
      AppLogger.i(
        'Obteniendo instancia: $instanceType/$instanceId del club $clubId',
        tag: _tag,
      );
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/clubs/$clubId/instances/$instanceType/$instanceId',
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = _unwrapMap(response.data);
        return ClubInstanceModel.fromJson(json, knownInstanceType: instanceType);
      }

      throw ServerException(
        message: 'Error al obtener instancia del club',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en getClubInstance', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? 'Error de red',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getClubInstance', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ClubInstanceModel> updateClubInstance({
    required String clubId,
    required String instanceType,
    required int instanceId,
    Map<String, dynamic>? data,
  }) async {
    try {
      AppLogger.i(
        'Actualizando instancia: $instanceType/$instanceId del club $clubId',
        tag: _tag,
      );
      final token = await _getAuthToken();

      final response = await _dio.patch(
        '$_baseUrl/clubs/$clubId/instances/$instanceType/$instanceId',
        data: data ?? {},
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = _unwrapMap(response.data);
        return ClubInstanceModel.fromJson(json, knownInstanceType: instanceType);
      }

      throw ServerException(
        message: 'Error al actualizar instancia del club',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en updateClubInstance', tag: _tag, error: e);
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message ?? 'Error de red')
          : (e.message ?? 'Error de red');
      throw ServerException(
        message: msg.toString(),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en updateClubInstance', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }
}
