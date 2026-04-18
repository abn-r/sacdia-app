import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/models/paginated_result.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/camporee_model.dart';
import '../models/camporee_member_model.dart';
import '../models/camporee_payment_model.dart';

/// Interfaz para la fuente de datos remota de camporees
abstract class CamporeesRemoteDataSource {
  /// Obtiene la lista de camporees, opcionalmente filtrando por activos.
  /// GET /api/v1/camporees
  Future<List<CamporeeModel>> getCamporees({bool? active, CancelToken? cancelToken});

  /// Obtiene el detalle de un camporee.
  /// GET /api/v1/camporees/:camporeeId
  Future<CamporeeModel> getCamporeeDetail(int camporeeId, {CancelToken? cancelToken});

  /// Registra un miembro en un camporee.
  /// POST /api/v1/camporees/:camporeeId/register
  Future<CamporeeMemberModel> registerMember(
    int camporeeId, {
    required String userId,
    required String camporeeType,
    String? clubName,
    int? insuranceId,
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

  /// Inscribe un club en un camporee.
  /// POST /api/v1/camporees/:camporeeId/clubs
  Future<CamporeeEnrolledClubModel> enrollClub(
    int camporeeId, {
    required int clubSectionId,
  });

  /// Obtiene los clubes inscritos en un camporee.
  /// GET /api/v1/camporees/:camporeeId/clubs
  Future<List<CamporeeEnrolledClubModel>> getEnrolledClubs(int camporeeId, {CancelToken? cancelToken});

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
  Future<List<CamporeePaymentModel>> getCamporeePayments(int camporeeId, {CancelToken? cancelToken});
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
        final msg = data['message'];
        if (msg is List) return msg.join(', ');
        return (msg ?? e.message ?? 'Error de conexion').toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? 'Error de conexion';
  }

  // ── GET /api/v1/camporees ────────────────────────────────────────────────────

  @override
  Future<List<CamporeeModel>> getCamporees({bool? active, CancelToken? cancelToken}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (active != null) queryParams['active'] = active;

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
            .map((json) =>
                CamporeeModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: 'Error al obtener camporees',
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getCamporees', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporees/:camporeeId ────────────────────────────────────────

  @override
  Future<CamporeeModel> getCamporeeDetail(int camporeeId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CamporeeModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: 'Error al obtener detalle del camporee',
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getCamporeeDetail', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /api/v1/camporees/:camporeeId/register ──────────────────────────────

  @override
  Future<CamporeeMemberModel> registerMember(
    int camporeeId, {
    required String userId,
    required String camporeeType,
    String? clubName,
    int? insuranceId,
  }) async {
    try {
      final body = <String, dynamic>{
        'user_id': userId,
        'camporee_type': camporeeType,
      };
      if (clubName != null) body['club_name'] = clubName;
      if (insuranceId != null) body['insurance_id'] = insuranceId;

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/register',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CamporeeMemberModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: 'Error al registrar miembro en el camporee',
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
              .map((e) => CamporeeMemberModel.fromJson(e as Map<String, dynamic>))
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
          message:
              'getCamporeeMembers: unexpected response type '
              '${responseData.runtimeType} — cannot parse members',
          code: response.statusCode,
        );
      }

      throw ServerException(
          message: 'Error al obtener miembros del camporee',
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
          message: 'Error al remover miembro del camporee',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en removeMember', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /api/v1/camporees/:camporeeId/clubs ──────────────────────────────

  @override
  Future<CamporeeEnrolledClubModel> enrollClub(
    int camporeeId, {
    required int clubSectionId,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/clubs',
        data: {'club_section_id': clubSectionId},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CamporeeEnrolledClubModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: 'Error al inscribir club en el camporee',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en enrollClub', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporees/:camporeeId/clubs ───────────────────────────────

  @override
  Future<List<CamporeeEnrolledClubModel>> getEnrolledClubs(
      int camporeeId, {CancelToken? cancelToken}) async {
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
          message: 'Error al obtener clubes inscritos',
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
        body['payment_date'] = paymentDate.toIso8601String();
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
          message: 'Error al registrar pago',
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
          message: 'Error al obtener pagos del miembro',
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getMemberPayments', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporees/:camporeeId/payments ────────────────────────────

  @override
  Future<List<CamporeePaymentModel>> getCamporeePayments(
      int camporeeId, {CancelToken? cancelToken}) async {
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
          message: 'Error al obtener pagos del camporee',
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getCamporeePayments', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
