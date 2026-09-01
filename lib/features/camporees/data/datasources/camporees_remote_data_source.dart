import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/models/paginated_result.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/camporee_score_submission.dart';
import '../models/camporee_judge_assignment_model.dart';
import '../models/camporee_leaderboard_model.dart';
import '../models/camporee_model.dart';
import '../models/camporee_event_model.dart';
import '../models/camporee_member_model.dart';
import '../models/camporee_payment_model.dart';
import '../models/camporee_rubric_model.dart';
import '../models/camporee_section_registration_model.dart';

/// Interfaz para la fuente de datos remota de camporees
abstract class CamporeesRemoteDataSource {
  /// Obtiene la lista de camporees, opcionalmente filtrando por activos.
  /// GET /api/v1/camporees
  Future<List<CamporeeModel>> getCamporees({
    bool? active,
    int? clubTypeId,
    CancelToken? cancelToken,
  });

  /// Obtiene el detalle de un camporee.
  /// GET /api/v1/camporees/:camporeeId
  Future<CamporeeModel> getCamporeeDetail(int camporeeId,
      {CancelToken? cancelToken});

  /// Obtiene la inscripción contextual de la sección activa.
  /// GET /api/v1/camporees/:camporeeId/section-registration
  Future<CamporeeSectionRegistrationModel> getActiveSectionRegistration(
    int camporeeId,
  );

  /// Inscribe la sección activa sin aceptar IDs controlados por el cliente.
  /// POST /api/v1/camporees/:camporeeId/section-registration
  Future<CamporeeSectionRegistrationModel> registerActiveSection(
    int camporeeId,
  );

  /// Obtiene preview seguro de eventos registrados de un camporee.
  /// GET /api/v1/local-camporees/:camporeeId/events/preview
  /// GET /api/v1/union-camporees/:camporeeId/events/preview
  Future<List<CamporeeEventModel>> getCamporeeEvents(
    int camporeeId, {
    String camporeeType = 'local',
    CancelToken? cancelToken,
  });

  /// Registra un miembro en un camporee.
  /// POST /api/v1/camporees/:camporeeId/register
  /// El backend infiere el tipo de camporee desde el endpoint; camporeeType se
  /// mantiene opcional por compatibilidad con despliegues anteriores.
  Future<CamporeeMemberModel> registerMember(
    int camporeeId, {
    required String userId,
    String? camporeeType,
    String? clubName,
    required int insuranceId,
  });

  /// Obtiene los miembros inscritos en un camporee (respuesta paginada).
  /// GET /api/v1/camporees/:camporeeId/members?page=&limit=&status=
  Future<PaginatedResult<CamporeeMemberModel>> getCamporeeMembers(
    int camporeeId, {
    int page = 1,
    int limit = 50,
    String? status,
    CancelToken? cancelToken,
  });

  /// Remueve un miembro de un camporee.
  /// DELETE /api/v1/camporees/:camporeeId/members/:userId
  Future<void> removeMember(int camporeeId, String userId);

  // ── Payments ────────────────────────────────────────────────────────────────

  /// Inscribe la sección activa del director en un camporee local.
  /// POST /api/v1/camporees/:camporeeId/section-registration
  Future<CamporeeEnrolledClubModel> enrollClub(int camporeeId);

  /// Obtiene los clubes inscritos en un camporee.
  /// GET /api/v1/camporees/:camporeeId/clubs
  Future<List<CamporeeEnrolledClubModel>> getEnrolledClubs(int camporeeId,
      {CancelToken? cancelToken});

  /// Crea un pago para un miembro en un camporee.
  /// POST /api/v1/camporees/:camporeeId/members/:memberId/payments
  Future<CamporeePaymentModel> createPayment(
    int camporeeId,
    String memberId, {
    required double amount,
    required String paymentType,
    String? reference,
    DateTime? paymentDate,
    String? notes,
  });

  /// Obtiene los pagos de un miembro en un camporee.
  /// GET /api/v1/camporees/:camporeeId/members/:memberId/payments
  Future<List<CamporeePaymentModel>> getMemberPayments(
    int camporeeId,
    String memberId, {
    CancelToken? cancelToken,
  });

  /// Obtiene todos los pagos de un camporee.
  /// GET /api/v1/camporees/:camporeeId/payments
  Future<List<CamporeePaymentModel>> getCamporeePayments(int camporeeId,
      {CancelToken? cancelToken});

  /// Obtiene asignaciones del juez autenticado.
  /// GET /api/v1/camporee-judges/me/assignments
  Future<List<CamporeeJudgeAssignmentModel>> getMyJudgeAssignments({
    CancelToken? cancelToken,
  });

  /// Obtiene la clasificación oficial de un camporee.
  /// GET /api/v1/local-camporees/:camporeeId/leaderboard
  /// GET /api/v1/union-camporees/:camporeeId/leaderboard
  Future<CamporeeLeaderboardModel> getCamporeeLeaderboard(
    int camporeeId, {
    String camporeeType = 'local',
    CancelToken? cancelToken,
  });

  /// Obtiene las rúbricas activas de un evento puntuable.
  /// GET /api/v1/camporee-events/:eventId/rubrics
  Future<List<CamporeeRubricModel>> getCamporeeEventRubrics(
    int eventId, {
    CancelToken? cancelToken,
  });

  /// Envía puntaje oficial del juez principal para una sección/evento.
  /// POST /api/v1/camporee-events/:eventId/sections/:clubSectionId/scores
  Future<void> submitCamporeeEventScore(
    int eventId,
    int clubSectionId, {
    required CamporeeScoreSubmission submission,
  });
}

/// Implementación de la fuente de datos remota de camporees.
///
/// Utiliza Dio para llamadas REST al backend SACDIA.
/// Auth token se lee desde [FlutterSecureStorage].
class CamporeesRemoteDataSourceImpl implements CamporeesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'CamporeesDS';

  CamporeesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      final msg = _extractDioMessage(e);
      throw ServerException(message: msg, code: e.response?.statusCode);
    }
    if (e is AppException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is List) return msg.join(', ');
        return (msg ?? e.message ?? tr('common.error_network')).toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? tr('common.error_network');
  }

  List<dynamic> _extractList(dynamic responseData) {
    if (responseData is Map && responseData['data'] is List) {
      return responseData['data'] as List<dynamic>;
    }
    if (responseData is List) return responseData;
    return const [];
  }

  Map<String, dynamic> _extractObject(dynamic responseData) {
    if (responseData is! Map) {
      throw FormatException(
        'Expected an object response, got ${responseData.runtimeType}',
      );
    }
    final map = Map<String, dynamic>.from(responseData);
    if (map.containsKey('data')) {
      final data = map['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      throw FormatException('Expected data to contain an object');
    }
    return map;
  }

  // ── GET /api/v1/camporees ────────────────────────────────────────────────────

  @override
  Future<List<CamporeeModel>> getCamporees({
    bool? active,
    int? clubTypeId,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (active != null) queryParams['active'] = active;
      if (clubTypeId != null) queryParams['club_type_id'] = clubTypeId;

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        List<dynamic> data;

        // Handle paginated response: { data: [...], total: N, ... }
        if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'] as List<dynamic>;
        } else if (responseData is List) {
          data = responseData;
        } else {
          data = [];
        }

        return data
            .map((json) => CamporeeModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: tr('camporees.errors.fetch_list'),
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getCamporees', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporees/:camporeeId ────────────────────────────────────────

  @override
  Future<CamporeeModel> getCamporeeDetail(int camporeeId,
      {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CamporeeModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: tr('camporees.errors.fetch_detail'),
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getCamporeeDetail', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporees/:camporeeId/section-registration ───────────────

  @override
  Future<CamporeeSectionRegistrationModel> getActiveSectionRegistration(
    int camporeeId,
  ) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/section-registration',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CamporeeSectionRegistrationModel.fromJson(
          _extractObject(response.data),
        );
      }

      throw ServerException(
        message: 'Unable to fetch active section registration',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e(
        'Error en getActiveSectionRegistration',
        tag: _tag,
        error: e,
      );
      _rethrow(e);
    }
  }

  // ── POST /api/v1/camporees/:camporeeId/section-registration ──────────────

  @override
  Future<CamporeeSectionRegistrationModel> registerActiveSection(
    int camporeeId,
  ) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/section-registration',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CamporeeSectionRegistrationModel.fromJson(
          _extractObject(response.data),
        );
      }

      throw ServerException(
        message: 'Unable to register active section',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en registerActiveSection', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/{local|union}-camporees/:camporeeId/events/preview ────────

  @override
  Future<List<CamporeeEventModel>> getCamporeeEvents(
    int camporeeId, {
    String camporeeType = 'local',
    CancelToken? cancelToken,
  }) async {
    try {
      final camporeePath =
          camporeeType == 'union' ? 'union-camporees' : 'local-camporees';
      final response = await _dio.get(
        '$_baseUrl/$camporeePath/$camporeeId/events/preview',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        final List<dynamic> data;
        if (responseData is Map && responseData['data'] is List) {
          data = responseData['data'] as List<dynamic>;
        } else if (responseData is List) {
          data = responseData;
        } else {
          data = const [];
        }

        return data
            .whereType<Map>()
            .map(
              (item) =>
                  CamporeeEventModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }

      throw ServerException(
        message: tr('camporees.errors.fetch_events'),
        code: response.statusCode,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getCamporeeEvents', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /api/v1/camporees/:camporeeId/register ──────────────────────────────

  @override
  Future<CamporeeMemberModel> registerMember(
    int camporeeId, {
    required String userId,
    String? camporeeType,
    String? clubName,
    required int insuranceId,
  }) async {
    try {
      final body = <String, dynamic>{
        'user_id': userId,
      };
      if (camporeeType != null && camporeeType.isNotEmpty) {
        body['camporee_type'] = camporeeType;
      }
      if (clubName != null) body['club_name'] = clubName;
      body['insurance_id'] = insuranceId;

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/register',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CamporeeMemberModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: tr('camporees.errors.register_member'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en registerMember', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporees/:camporeeId/members ────────────────────────────────

  @override
  Future<PaginatedResult<CamporeeMemberModel>> getCamporeeMembers(
    int camporeeId, {
    int page = 1,
    int limit = 50,
    String? status,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/members',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        // Backend now always returns { data: [...], meta: {...} }.
        // Guard against legacy raw-array responses during transition.
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('data') &&
            responseData.containsKey('meta')) {
          return PaginatedResult.fromJson(
            responseData,
            CamporeeMemberModel.fromJson,
          );
        }

        // Fallback: raw array (should not happen post-migration).
        if (responseData is List) {
          AppLogger.w(
            'getCamporeeMembers: backend returned raw array instead of '
            'paginated object — post-migration this should not happen',
            tag: _tag,
          );
          final members = responseData
              .map((e) =>
                  CamporeeMemberModel.fromJson(e as Map<String, dynamic>))
              .toList();
          return PaginatedResult<CamporeeMemberModel>(
            data: members,
            meta: PaginationMeta(
              page: page,
              limit: limit,
              total: members.length,
              totalPages: 1,
              hasNextPage: false,
              hasPreviousPage: false,
            ),
          );
        }

        // Malformed: neither Map-with-data nor List — fail visibly.
        throw ServerException(
          message: 'getCamporeeMembers: unexpected response type '
              '${responseData.runtimeType} — cannot parse members',
          code: response.statusCode,
        );
      }

      throw ServerException(
          message: tr('camporees.errors.fetch_members'),
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getCamporeeMembers', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /api/v1/camporees/:camporeeId/members/:userId ─────────────────────

  @override
  Future<void> removeMember(int camporeeId, String userId) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/members/$userId',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
          message: tr('camporees.errors.remove_member'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en removeMember', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /api/v1/camporees/:camporeeId/section-registration ─────────────

  @override
  Future<CamporeeEnrolledClubModel> enrollClub(int camporeeId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/section-registration',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CamporeeEnrolledClubModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: tr('camporees.errors.enroll_club'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en enrollClub', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporees/:camporeeId/clubs ───────────────────────────────

  @override
  Future<List<CamporeeEnrolledClubModel>> getEnrolledClubs(int camporeeId,
      {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/clubs',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        List<dynamic> data;

        if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'] as List<dynamic>;
        } else if (responseData is List) {
          data = responseData;
        } else {
          data = [];
        }

        return data
            .map((json) => CamporeeEnrolledClubModel.fromJson(
                json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: tr('camporees.errors.fetch_enrolled_clubs'),
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getEnrolledClubs', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /api/v1/camporees/:camporeeId/members/:memberId/payments ─────────

  @override
  Future<CamporeePaymentModel> createPayment(
    int camporeeId,
    String memberId, {
    required double amount,
    required String paymentType,
    String? reference,
    DateTime? paymentDate,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'amount': amount,
        'payment_type': paymentType,
      };
      if (reference != null) body['reference'] = reference;
      if (paymentDate != null) {
        body['paid_at'] = paymentDate.toIso8601String();
      }
      if (notes != null) body['notes'] = notes;

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/members/$memberId/payments',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CamporeePaymentModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: tr('camporees.errors.create_payment'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en createPayment', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporees/:camporeeId/members/:memberId/payments ──────────

  @override
  Future<List<CamporeePaymentModel>> getMemberPayments(
    int camporeeId,
    String memberId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/members/$memberId/payments',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        List<dynamic> data;

        if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'] as List<dynamic>;
        } else if (responseData is List) {
          data = responseData;
        } else {
          data = [];
        }

        return data
            .map((json) =>
                CamporeePaymentModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: tr('camporees.errors.fetch_member_payments'),
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getMemberPayments', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporees/:camporeeId/payments ────────────────────────────

  @override
  Future<List<CamporeePaymentModel>> getCamporeePayments(int camporeeId,
      {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/payments',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        List<dynamic> data;

        if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'] as List<dynamic>;
        } else if (responseData is List) {
          data = responseData;
        } else {
          data = [];
        }

        return data
            .map((json) =>
                CamporeePaymentModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: tr('camporees.errors.fetch_camporee_payments'),
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getCamporeePayments', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporee-judges/me/assignments ───────────────────────────

  @override
  Future<List<CamporeeJudgeAssignmentModel>> getMyJudgeAssignments({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/camporee-judges/me/assignments',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _extractList(response.data)
            .whereType<Map<String, dynamic>>()
            .map(CamporeeJudgeAssignmentModel.fromJson)
            .toList();
      }

      throw ServerException(
        message: tr('camporees.errors.fetch_judge_assignments'),
        code: response.statusCode,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getMyJudgeAssignments', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/{local|union}-camporees/:camporeeId/leaderboard ───────────

  @override
  Future<CamporeeLeaderboardModel> getCamporeeLeaderboard(
    int camporeeId, {
    String camporeeType = 'local',
    CancelToken? cancelToken,
  }) async {
    try {
      final camporeePath =
          camporeeType == 'union' ? 'union-camporees' : 'local-camporees';
      final response = await _dio.get(
        '$_baseUrl/$camporeePath/$camporeeId/leaderboard',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CamporeeLeaderboardModel.fromJson(
          _extractObject(response.data),
        );
      }

      throw ServerException(
        message: tr('camporees.errors.fetch_leaderboard'),
        code: response.statusCode,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getCamporeeLeaderboard', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporee-events/:eventId/rubrics ─────────────────────────

  @override
  Future<List<CamporeeRubricModel>> getCamporeeEventRubrics(
    int eventId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/camporee-events/$eventId/rubrics',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _extractList(response.data)
            .whereType<Map<String, dynamic>>()
            .map(CamporeeRubricModel.fromJson)
            .toList();
      }

      throw ServerException(
        message: tr('camporees.errors.fetch_event_rubrics'),
        code: response.statusCode,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getCamporeeEventRubrics', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /api/v1/camporee-events/:eventId/sections/:sectionId/scores ──────

  @override
  Future<void> submitCamporeeEventScore(
    int eventId,
    int clubSectionId, {
    required CamporeeScoreSubmission submission,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/camporee-events/$eventId/sections/$clubSectionId/scores',
        data: submission.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      throw ServerException(
        message: tr('camporees.errors.submit_score'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en submitCamporeeEventScore', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
