import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/unit_member_model.dart';
import '../models/unit_model.dart';
import '../models/weekly_record_model.dart';

/// Interfaz de la fuente de datos remota para el módulo de unidades.
abstract class UnitsRemoteDataSource {
  /// Retorna todas las unidades activas de un club.
  Future<List<UnitModel>> getClubUnits({required int clubId});

  /// Retorna el detalle de una unidad con sus miembros activos.
  Future<UnitModel> getUnitDetail({required int clubId, required int unitId});

  /// Crea una nueva unidad en el club.
  Future<UnitModel> createUnit({
    required int clubId,
    required String name,
    required String captainId,
    required String secretaryId,
    required String advisorId,
    String? substituteAdvisorId,
    required int clubTypeId,
    int? clubSectionId,
  });

  /// Actualiza una unidad existente.
  Future<UnitModel> updateUnit({
    required int clubId,
    required int unitId,
    String? name,
    String? captainId,
    String? secretaryId,
    String? advisorId,
    String? substituteAdvisorId,
    int? clubTypeId,
    int? clubSectionId,
    bool? active,
  });

  /// Elimina (soft-delete) una unidad.
  Future<void> deleteUnit({required int clubId, required int unitId});

  /// Agrega un miembro a la unidad.
  Future<UnitMemberModel> addUnitMember({
    required int clubId,
    required int unitId,
    required String userId,
  });

  /// Remueve un miembro de la unidad.
  Future<void> removeUnitMember({
    required int clubId,
    required int unitId,
    required int memberId,
  });

  /// Retorna los registros semanales de una unidad.
  Future<List<WeeklyRecordModel>> getWeeklyRecords({
    required int clubId,
    required int unitId,
  });

  /// Crea un registro semanal para un miembro de la unidad.
  Future<WeeklyRecordModel> createWeeklyRecord({
    required int clubId,
    required int unitId,
    required String userId,
    required int week,
    required int attendance,
    required int punctuality,
    required int points,
  });

  /// Actualiza un registro semanal existente.
  Future<WeeklyRecordModel> updateWeeklyRecord({
    required int clubId,
    required int unitId,
    required int recordId,
    int? attendance,
    int? punctuality,
    int? points,
    bool? active,
  });
}

/// Implementación de la fuente de datos remota para unidades.
///
/// Todos los endpoints bajo: /api/v1/clubs/:clubId/units
class UnitsRemoteDataSourceImpl implements UnitsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'UnitsDS';

  UnitsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<String> _getAuthToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) throw AuthException(message: 'No hay sesión activa');
    return token;
  }

  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  String _unitsBase(int clubId) => '$_baseUrl/clubs/$clubId/units';

  // ── GET /clubs/:clubId/units ───────────────────────────────────────────────

  @override
  Future<List<UnitModel>> getClubUnits({required int clubId}) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        _unitsBase(clubId),
        options: _authOptions(token),
      );

      _assertSuccess(response, 'Error al obtener las unidades del club');

      final body = response.data;
      final List<dynamic> rawList = body is List
          ? body
          : (body as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];

      return rawList
          .map((e) => UnitModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error en getClubUnits', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/units/:unitId ──────────────────────────────────────

  @override
  Future<UnitModel> getUnitDetail({
    required int clubId,
    required int unitId,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '${_unitsBase(clubId)}/$unitId',
        options: _authOptions(token),
      );

      _assertSuccess(response, 'Error al obtener el detalle de la unidad');

      final json = _extractObject(response.data);
      return UnitModel.fromJson(json);
    } catch (e) {
      AppLogger.e('Error en getUnitDetail', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /clubs/:clubId/units ──────────────────────────────────────────────

  @override
  Future<UnitModel> createUnit({
    required int clubId,
    required String name,
    required String captainId,
    required String secretaryId,
    required String advisorId,
    String? substituteAdvisorId,
    required int clubTypeId,
    int? clubSectionId,
  }) async {
    try {
      final token = await _getAuthToken();
      final body = <String, dynamic>{
        'name': name,
        'captain_id': captainId,
        'secretary_id': secretaryId,
        'advisor_id': advisorId,
        if (substituteAdvisorId != null)
          'substitute_advisor_id': substituteAdvisorId,
        'club_type_id': clubTypeId,
        if (clubSectionId != null) 'club_section_id': clubSectionId,
      };

      final response = await _dio.post(
        _unitsBase(clubId),
        data: body,
        options: _authOptions(token),
      );

      _assertSuccess(response, 'Error al crear la unidad');

      final json = _extractObject(response.data);
      return UnitModel.fromJson(json);
    } catch (e) {
      AppLogger.e('Error en createUnit', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── PATCH /clubs/:clubId/units/:unitId ────────────────────────────────────

  @override
  Future<UnitModel> updateUnit({
    required int clubId,
    required int unitId,
    String? name,
    String? captainId,
    String? secretaryId,
    String? advisorId,
    String? substituteAdvisorId,
    int? clubTypeId,
    int? clubSectionId,
    bool? active,
  }) async {
    try {
      final token = await _getAuthToken();
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (captainId != null) 'captain_id': captainId,
        if (secretaryId != null) 'secretary_id': secretaryId,
        if (advisorId != null) 'advisor_id': advisorId,
        if (substituteAdvisorId != null)
          'substitute_advisor_id': substituteAdvisorId,
        if (clubTypeId != null) 'club_type_id': clubTypeId,
        if (clubSectionId != null) 'club_section_id': clubSectionId,
        if (active != null) 'active': active,
      };

      final response = await _dio.patch(
        '${_unitsBase(clubId)}/$unitId',
        data: body,
        options: _authOptions(token),
      );

      _assertSuccess(response, 'Error al actualizar la unidad');

      final json = _extractObject(response.data);
      return UnitModel.fromJson(json);
    } catch (e) {
      AppLogger.e('Error en updateUnit', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /clubs/:clubId/units/:unitId ───────────────────────────────────

  @override
  Future<void> deleteUnit({required int clubId, required int unitId}) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.delete(
        '${_unitsBase(clubId)}/$unitId',
        options: _authOptions(token),
      );
      _assertSuccess(response, 'Error al eliminar la unidad');
    } catch (e) {
      AppLogger.e('Error en deleteUnit', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /clubs/:clubId/units/:unitId/members ─────────────────────────────

  @override
  Future<UnitMemberModel> addUnitMember({
    required int clubId,
    required int unitId,
    required String userId,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.post(
        '${_unitsBase(clubId)}/$unitId/members',
        data: {'user_id': userId},
        options: _authOptions(token),
      );

      _assertSuccess(response, 'Error al agregar el miembro a la unidad');

      final json = _extractObject(response.data);
      return UnitMemberModel.fromJson(json);
    } catch (e) {
      AppLogger.e('Error en addUnitMember', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /clubs/:clubId/units/:unitId/members/:memberId ─────────────────

  @override
  Future<void> removeUnitMember({
    required int clubId,
    required int unitId,
    required int memberId,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.delete(
        '${_unitsBase(clubId)}/$unitId/members/$memberId',
        options: _authOptions(token),
      );
      _assertSuccess(response, 'Error al remover el miembro de la unidad');
    } catch (e) {
      AppLogger.e('Error en removeUnitMember', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/units/:unitId/weekly-records ───────────────────────

  @override
  Future<List<WeeklyRecordModel>> getWeeklyRecords({
    required int clubId,
    required int unitId,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '${_unitsBase(clubId)}/$unitId/weekly-records',
        options: _authOptions(token),
      );

      _assertSuccess(response, 'Error al obtener los registros semanales');

      final body = response.data;
      final List<dynamic> rawList = body is List
          ? body
          : (body as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];

      return rawList
          .map((e) => WeeklyRecordModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error en getWeeklyRecords', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /clubs/:clubId/units/:unitId/weekly-records ──────────────────────

  @override
  Future<WeeklyRecordModel> createWeeklyRecord({
    required int clubId,
    required int unitId,
    required String userId,
    required int week,
    required int attendance,
    required int punctuality,
    required int points,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.post(
        '${_unitsBase(clubId)}/$unitId/weekly-records',
        data: {
          'user_id': userId,
          'week': week,
          'attendance': attendance,
          'punctuality': punctuality,
          'points': points,
        },
        options: _authOptions(token),
      );

      _assertSuccess(response, 'Error al crear el registro semanal');

      final json = _extractObject(response.data);
      return WeeklyRecordModel.fromJson(json);
    } catch (e) {
      AppLogger.e('Error en createWeeklyRecord', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── PATCH /clubs/:clubId/units/:unitId/weekly-records/:recordId ───────────

  @override
  Future<WeeklyRecordModel> updateWeeklyRecord({
    required int clubId,
    required int unitId,
    required int recordId,
    int? attendance,
    int? punctuality,
    int? points,
    bool? active,
  }) async {
    try {
      final token = await _getAuthToken();
      final body = <String, dynamic>{
        if (attendance != null) 'attendance': attendance,
        if (punctuality != null) 'punctuality': punctuality,
        if (points != null) 'points': points,
        if (active != null) 'active': active,
      };

      final response = await _dio.patch(
        '${_unitsBase(clubId)}/$unitId/weekly-records/$recordId',
        data: body,
        options: _authOptions(token),
      );

      _assertSuccess(response, 'Error al actualizar el registro semanal');

      final json = _extractObject(response.data);
      return WeeklyRecordModel.fromJson(json);
    } catch (e) {
      AppLogger.e('Error en updateWeeklyRecord', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _assertSuccess(Response response, String fallbackMsg) {
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw ServerException(message: fallbackMsg, code: code);
    }
  }

  Map<String, dynamic> _extractObject(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body.containsKey('data')
          ? body['data'] as Map<String, dynamic>
          : body;
    }
    throw ServerException(message: 'Respuesta inesperada del servidor');
  }

  Never _rethrow(Object e) {
    if (e is DioException) {
      final msg = _extractDioMessage(e);
      throw ServerException(message: msg, code: e.response?.statusCode);
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return (data['message'] ?? e.message ?? 'Error de conexión').toString();
      }
    } catch (_) {}
    return e.message ?? 'Error de conexión';
  }
}
