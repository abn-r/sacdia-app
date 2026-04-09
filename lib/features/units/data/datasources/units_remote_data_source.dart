import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/member_of_month_model.dart';
import '../models/scoring_category_model.dart';
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
  ///
  /// [scores] es la lista de puntajes por categoría:
  /// `[{ 'category_id': 1, 'points': 5 }, ...]`
  Future<WeeklyRecordModel> createWeeklyRecord({
    required int clubId,
    required int unitId,
    required String userId,
    required int week,
    required int year,
    required int attendance,
    int punctuality = 0,
    List<Map<String, int>> scores = const [],
  });

  /// Actualiza un registro semanal existente.
  ///
  /// [scores] es la lista de puntajes por categoría (actualización parcial).
  Future<WeeklyRecordModel> updateWeeklyRecord({
    required int clubId,
    required int unitId,
    required int recordId,
    int? attendance,
    List<Map<String, int>>? scores,
    bool? active,
  });

  /// Retorna las categorías de puntuación activas para un campo local.
  Future<List<ScoringCategoryModel>> getScoringCategories({
    required int localFieldId,
  });

  /// Retorna el Miembro del Mes actual de una sección del club.
  /// Retorna null si no hay datos para el mes actual.
  Future<MemberOfMonthModel?> getMemberOfMonth({
    required int clubId,
    required int sectionId,
  });

  /// Retorna el historial paginado de Miembros del Mes de una sección.
  Future<Map<String, dynamic>> getMemberOfMonthHistory({
    required int clubId,
    required int sectionId,
    int page = 1,
    int limit = 12,
  });
}

/// Implementación de la fuente de datos remota para unidades.
///
/// Todos los endpoints bajo: /api/v1/clubs/:clubId/units
class UnitsRemoteDataSourceImpl implements UnitsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'UnitsDS';

  UnitsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  String _unitsBase(int clubId) => '$_baseUrl${ApiEndpoints.clubs}/$clubId/units';

  // ── GET /clubs/:clubId/units ───────────────────────────────────────────────

  @override
  Future<List<UnitModel>> getClubUnits({required int clubId}) async {
    try {
      final response = await _dio.get(
        _unitsBase(clubId),
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
      final response = await _dio.get(
        '${_unitsBase(clubId)}/$unitId',
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
      final response = await _dio.delete(
        '${_unitsBase(clubId)}/$unitId',
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
      final response = await _dio.post(
        '${_unitsBase(clubId)}/$unitId/members',
        data: {'user_id': userId},
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
      final response = await _dio.delete(
        '${_unitsBase(clubId)}/$unitId/members/$memberId',
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
      final response = await _dio.get(
        '${_unitsBase(clubId)}/$unitId/weekly-records',
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
    required int year,
    required int attendance,
    int punctuality = 0,
    List<Map<String, int>> scores = const [],
  }) async {
    try {
      final body = <String, dynamic>{
        'user_id': userId,
        'week': week,
        'year': year,
        'attendance': attendance,
        'punctuality': punctuality,
        if (scores.isNotEmpty) 'scores': scores,
      };

      final response = await _dio.post(
        '${_unitsBase(clubId)}/$unitId/weekly-records',
        data: body,
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
    List<Map<String, int>>? scores,
    bool? active,
  }) async {
    try {
      final body = <String, dynamic>{
        if (attendance != null) 'attendance': attendance,
        if (scores != null && scores.isNotEmpty) 'scores': scores,
        if (active != null) 'active': active,
      };

      final response = await _dio.patch(
        '${_unitsBase(clubId)}/$unitId/weekly-records/$recordId',
        data: body,
      );

      _assertSuccess(response, 'Error al actualizar el registro semanal');

      final json = _extractObject(response.data);
      return WeeklyRecordModel.fromJson(json);
    } catch (e) {
      AppLogger.e('Error en updateWeeklyRecord', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /local-fields/:fieldId/scoring-categories ─────────────────────────

  @override
  Future<List<ScoringCategoryModel>> getScoringCategories({
    required int localFieldId,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/local-fields/$localFieldId/scoring-categories',
      );

      _assertSuccess(response, 'Error al obtener las categorías de puntuación');

      final body = response.data;
      final List<dynamic> rawList = body is List
          ? body
          : (body as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];

      return rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => ScoringCategoryModel.fromJson(e))
          .toList();
    } catch (e) {
      AppLogger.e('Error en getScoringCategories', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/sections/:sectionId/member-of-month ────────────────

  @override
  Future<MemberOfMonthModel?> getMemberOfMonth({
    required int clubId,
    required int sectionId,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/member-of-month',
      );

      _assertSuccess(response, 'Error al obtener el miembro del mes');

      final body = response.data;
      // Si el backend retorna null o un objeto sin members, no hay datos.
      if (body == null) return null;

      final json = body is Map<String, dynamic>
          ? body
          : (body['data'] as Map<String, dynamic>?);
      if (json == null) return null;

      final model = MemberOfMonthModel.fromJson(json);
      // Si no hay miembros, la evaluación aún no corrió — tratar como null.
      if (model.members.isEmpty) return null;

      return model;
    } on DioException catch (e) {
      // 404 significa que no hay datos para el mes actual — retornar null.
      if (e.response?.statusCode == 404) return null;
      AppLogger.e('Error en getMemberOfMonth', tag: _tag, error: e);
      _rethrow(e);
    } catch (e) {
      AppLogger.e('Error en getMemberOfMonth', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/sections/:sectionId/member-of-month/history ─────────

  @override
  Future<Map<String, dynamic>> getMemberOfMonthHistory({
    required int clubId,
    required int sectionId,
    int page = 1,
    int limit = 12,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/member-of-month/history',
        queryParameters: {'page': page, 'limit': limit},
      );

      _assertSuccess(
          response, 'Error al obtener el historial de miembro del mes');

      final body = response.data;
      if (body is Map<String, dynamic>) return body;
      return {'data': body, 'pagination': {}};
    } catch (e) {
      AppLogger.e('Error en getMemberOfMonthHistory', tag: _tag, error: e);
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
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? 'Error de conexión';
  }
}
