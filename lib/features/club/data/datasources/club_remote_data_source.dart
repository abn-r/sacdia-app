import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/club_info_model.dart';

/// Interfaz para la fuente de datos remota del módulo de club.
abstract class ClubRemoteDataSource {
  /// Obtiene el club contenedor.
  Future<ClubInfoModel> getClub(String clubId);

  /// Obtiene la sección de club por ID.
  Future<ClubSectionModel> getClubSection({
    required String clubId,
    required int sectionId,
  });

  /// Actualiza una sección de club (PATCH).
  Future<ClubSectionModel> updateClubSection({
    required String clubId,
    required int sectionId,
    Map<String, dynamic>? data,
  });
}

/// Implementación de [ClubRemoteDataSource] usando Dio.
class ClubRemoteDataSourceImpl implements ClubRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'ClubDS';

  ClubRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

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

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId',
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
  Future<ClubSectionModel> getClubSection({
    required String clubId,
    required int sectionId,
  }) async {
    try {
      AppLogger.i('Obteniendo sección: $sectionId del club $clubId', tag: _tag);

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = _unwrapMap(response.data);
        return ClubSectionModel.fromJson(json);
      }

      throw ServerException(
        message: 'Error al obtener sección del club',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en getClubSection', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? 'Error de red',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getClubSection', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ClubSectionModel> updateClubSection({
    required String clubId,
    required int sectionId,
    Map<String, dynamic>? data,
  }) async {
    try {
      AppLogger.i(
        'Actualizando sección: $sectionId del club $clubId',
        tag: _tag,
      );
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId',
        data: data ?? {},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = _unwrapMap(response.data);
        return ClubSectionModel.fromJson(json);
      }

      throw ServerException(
        message: 'Error al actualizar sección del club',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en updateClubSection', tag: _tag, error: e);
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message ?? 'Error de red')
          : (e.message ?? 'Error de red');
      throw ServerException(
        message: msg.toString(),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en updateClubSection', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }
}
