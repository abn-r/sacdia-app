import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/camporee_model.dart';
import '../models/camporee_member_model.dart';
import '../models/camporee_payment_model.dart';

/// Interfaz para la fuente de datos remota de camporees
abstract class CamporeesRemoteDataSource {
  /// Obtiene la lista de camporees, opcionalmente filtrando por activos.
  /// GET /api/v1/camporees
  Future<List<CamporeeModel>> getCamporees({bool? active});

  /// Obtiene el detalle de un camporee.
  /// GET /api/v1/camporees/:camporeeId
  Future<CamporeeModel> getCamporeeDetail(int camporeeId);

  /// Registra un miembro en un camporee.
  /// POST /api/v1/camporees/:camporeeId/register
  Future<CamporeeMemberModel> registerMember(
    int camporeeId, {
    required String userId,
    required String camporeeType,
    String? clubName,
    int? insuranceId,
  });

  /// Obtiene los miembros inscritos en un camporee.
  /// GET /api/v1/camporees/:camporeeId/members
  Future<List<CamporeeMemberModel>> getCamporeeMembers(int camporeeId);

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

  /// Obtiene los clubes inscriptos en un camporee.
  /// GET /api/v1/camporees/:camporeeId/clubs
  Future<List<CamporeeEnrolledClubModel>> getEnrolledClubs(int camporeeId);

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
    String memberId,
  );

  /// Obtiene todos los pagos de un camporee.
  /// GET /api/v1/camporees/:camporeeId/payments
  Future<List<CamporeePaymentModel>> getCamporeePayments(int camporeeId);
}

/// Implementación de la fuente de datos remota de camporees.
///
/// Utiliza Dio para llamadas REST al backend SACDIA.
/// Auth token se lee desde [FlutterSecureStorage].
class CamporeesRemoteDataSourceImpl implements CamporeesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'CamporeesDS';

  CamporeesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  Future<String> _getAuthToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) {
      throw AuthException(message: 'No hay sesion activa');
    }
    return token;
  }

  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

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
  Future<List<CamporeeModel>> getCamporees({bool? active}) async {
    try {
      final token = await _getAuthToken();
      final queryParams = <String, dynamic>{};
      if (active != null) queryParams['active'] = active;

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: _authOptions(token),
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
      AppLogger.e('Error en getCamporees', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporees/:camporeeId ────────────────────────────────────────

  @override
  Future<CamporeeModel> getCamporeeDetail(int camporeeId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CamporeeModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: 'Error al obtener detalle del camporee',
          code: response.statusCode);
    } catch (e) {
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
      final token = await _getAuthToken();
      final body = <String, dynamic>{
        'user_id': userId,
        'camporee_type': camporeeType,
      };
      if (clubName != null) body['club_name'] = clubName;
      if (insuranceId != null) body['insurance_id'] = insuranceId;

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/register',
        data: body,
        options: _authOptions(token),
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
  Future<List<CamporeeMemberModel>> getCamporeeMembers(int camporeeId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/members',
        options: _authOptions(token),
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
                CamporeeMemberModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: 'Error al obtener miembros del camporee',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getCamporeeMembers', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /api/v1/camporees/:camporeeId/members/:userId ─────────────────────

  @override
  Future<void> removeMember(int camporeeId, String userId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/members/$userId',
        options: _authOptions(token),
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
      final token = await _getAuthToken();
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/clubs',
        data: {'club_section_id': clubSectionId},
        options: _authOptions(token),
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
      int camporeeId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/clubs',
        options: _authOptions(token),
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
          message: 'Error al obtener clubes inscriptos',
          code: response.statusCode);
    } catch (e) {
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
      final token = await _getAuthToken();
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
        options: _authOptions(token),
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
    String memberId,
  ) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/members/$memberId/payments',
        options: _authOptions(token),
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
      AppLogger.e('Error en getMemberPayments', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/camporees/:camporeeId/payments ────────────────────────────

  @override
  Future<List<CamporeePaymentModel>> getCamporeePayments(
      int camporeeId) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/payments',
        options: _authOptions(token),
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
      AppLogger.e('Error en getCamporeePayments', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
