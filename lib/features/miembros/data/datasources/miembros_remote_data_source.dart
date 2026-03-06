import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/club_member_model.dart';
import '../models/join_request_model.dart';

/// Interfaz de la fuente de datos remota para miembros
abstract class MiembrosRemoteDataSource {
  /// Obtiene los miembros de una instancia de club
  Future<List<ClubMemberModel>> getClubMembers({
    required int clubId,
    required String instanceType,
    required int instanceId,
  });

  /// Obtiene el perfil de un miembro específico
  Future<ClubMemberModel> getMemberDetail(String userId);

  /// Obtiene solicitudes de ingreso al club
  Future<List<JoinRequestModel>> getJoinRequests({
    required int clubId,
    required String instanceType,
    required int instanceId,
  });

  /// Aprueba una solicitud de ingreso
  Future<JoinRequestModel> approveJoinRequest(int requestId);

  /// Rechaza una solicitud de ingreso
  Future<JoinRequestModel> rejectJoinRequest(int requestId);

  /// Asigna un rol a un miembro en una instancia del club
  Future<bool> assignClubRole({
    required int clubId,
    required String instanceType,
    required int instanceId,
    required String userId,
    required String role,
  });

  /// Remueve una asignación de rol
  Future<bool> removeClubRole(int assignmentId);
}

/// Implementación de la fuente de datos remota para miembros
class MiembrosRemoteDataSourceImpl implements MiembrosRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'MiembrosDS';

  MiembrosRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
      };

  /// Desenvuelve la respuesta de la API que puede venir como
  /// { "status": "success", "data": [...] } o directamente como [...]
  List<Map<String, dynamic>> _unwrapList(dynamic responseData) {
    if (responseData is List) {
      return responseData.cast<Map<String, dynamic>>();
    }
    if (responseData is Map) {
      final data = responseData['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      // Algunos endpoints anidan en { data: { members: [...] } }
      if (data is Map) {
        final members = data['members'] ?? data['items'] ?? data['results'];
        if (members is List) return members.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  Map<String, dynamic> _unwrapMap(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('data') &&
          responseData['data'] is Map<String, dynamic>) {
        return responseData['data'] as Map<String, dynamic>;
      }
      return responseData;
    }
    return {};
  }

  @override
  Future<List<ClubMemberModel>> getClubMembers({
    required int clubId,
    required String instanceType,
    required int instanceId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw AuthException(message: 'No hay sesión activa');

      final response = await _dio.get(
        '$_baseUrl/clubs/$clubId/instances/$instanceType/$instanceId/members',
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Error al obtener miembros del club',
          code: response.statusCode,
        );
      }

      final list = _unwrapList(response.data);
      return list.map((json) => ClubMemberModel.fromJson(json)).toList();
    } on DioException catch (e) {
      AppLogger.e('Error al obtener miembros', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al obtener miembros',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getClubMembers', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ClubMemberModel> getMemberDetail(String userId) async {
    try {
      final token = await _getToken();
      if (token == null) throw AuthException(message: 'No hay sesión activa');

      final response = await _dio.get(
        '$_baseUrl/users/$userId',
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Error al obtener detalle del miembro',
          code: response.statusCode,
        );
      }

      final json = _unwrapMap(response.data);
      return ClubMemberModel.fromJson(json);
    } on DioException catch (e) {
      AppLogger.e('Error al obtener detalle del miembro', tag: _tag, error: e);
      throw ServerException(
        message:
            e.response?.data?['message'] ?? 'Error al obtener detalle del miembro',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getMemberDetail', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<JoinRequestModel>> getJoinRequests({
    required int clubId,
    required String instanceType,
    required int instanceId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw AuthException(message: 'No hay sesión activa');

      // El backend actualmente expone miembros; las solicitudes de ingreso
      // se obtienen filtrando por estado pendiente o desde un endpoint
      // dedicado cuando esté disponible. Por ahora consultamos el endpoint
      // de miembros con parámetro de estado, o retornamos lista vacía si
      // el endpoint aún no existe.
      final response = await _dio.get(
        '$_baseUrl/clubs/$clubId/instances/$instanceType/$instanceId/members',
        queryParameters: {'status': 'pending'},
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Error al obtener solicitudes de ingreso',
          code: response.statusCode,
        );
      }

      final list = _unwrapList(response.data);
      // Filtrar sólo registros con status pending si la API los incluye todos
      return list
          .map((json) => JoinRequestModel.fromJson(json))
          .where((r) => r.status == _pendingStatus())
          .toList();
    } on DioException catch (e) {
      // Si es 404 u otro error de recurso no encontrado, retornar lista vacía
      if (e.response?.statusCode == 404 ||
          e.response?.statusCode == 400) {
        AppLogger.w('Endpoint de solicitudes no disponible', tag: _tag);
        return [];
      }
      AppLogger.e('Error al obtener solicitudes', tag: _tag, error: e);
      throw ServerException(
        message:
            e.response?.data?['message'] ?? 'Error al obtener solicitudes',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getJoinRequests', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  // Helper para evitar import de la entidad en el data source
  dynamic _pendingStatus() {
    return null; // Se filtra en el use case o repositorio si es necesario
  }

  @override
  Future<JoinRequestModel> approveJoinRequest(int requestId) async {
    try {
      final token = await _getToken();
      if (token == null) throw AuthException(message: 'No hay sesión activa');

      final response = await _dio.patch(
        '$_baseUrl/club-roles/$requestId',
        data: {'status': 'approved'},
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Error al aprobar solicitud',
          code: response.statusCode,
        );
      }

      final json = _unwrapMap(response.data);
      return JoinRequestModel.fromJson({...json, 'status': 'approved'});
    } on DioException catch (e) {
      AppLogger.e('Error al aprobar solicitud', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al aprobar solicitud',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<JoinRequestModel> rejectJoinRequest(int requestId) async {
    try {
      final token = await _getToken();
      if (token == null) throw AuthException(message: 'No hay sesión activa');

      final response = await _dio.patch(
        '$_baseUrl/club-roles/$requestId',
        data: {'status': 'rejected'},
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: 'Error al rechazar solicitud',
          code: response.statusCode,
        );
      }

      final json = _unwrapMap(response.data);
      return JoinRequestModel.fromJson({...json, 'status': 'rejected'});
    } on DioException catch (e) {
      AppLogger.e('Error al rechazar solicitud', tag: _tag, error: e);
      throw ServerException(
        message:
            e.response?.data?['message'] ?? 'Error al rechazar solicitud',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<bool> assignClubRole({
    required int clubId,
    required String instanceType,
    required int instanceId,
    required String userId,
    required String role,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw AuthException(message: 'No hay sesión activa');

      final response = await _dio.post(
        '$_baseUrl/clubs/$clubId/instances/$instanceType/$instanceId/roles',
        data: {
          'user_id': userId,
          'role': role,
        },
        options: Options(headers: _authHeaders(token)),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      AppLogger.e('Error al asignar rol', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al asignar rol',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<bool> removeClubRole(int assignmentId) async {
    try {
      final token = await _getToken();
      if (token == null) throw AuthException(message: 'No hay sesión activa');

      final response = await _dio.delete(
        '$_baseUrl/club-roles/$assignmentId',
        options: Options(headers: _authHeaders(token)),
      );

      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } on DioException catch (e) {
      AppLogger.e('Error al remover rol', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al remover rol',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}
