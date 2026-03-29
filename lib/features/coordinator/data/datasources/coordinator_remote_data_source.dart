import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/evidence_review_item.dart';
import '../../domain/entities/camporee_approval.dart';
import '../models/sla_dashboard_model.dart';
import '../models/evidence_review_model.dart';
import '../models/camporee_approval_model.dart';

/// Interfaz para la fuente de datos remota del coordinador.
abstract class CoordinatorRemoteDataSource {
  /// GET /admin/analytics/sla-dashboard
  Future<SlaDashboardModel> getSlaDashboard();

  /// GET /evidence-review/pending?page=1&limit=20&type=folder|class|honor
  Future<List<EvidenceReviewItemModel>> getPendingEvidence({
    int page = 1,
    int limit = 20,
    EvidenceReviewType? type,
  });

  /// GET /evidence-review/:type/:id
  Future<EvidenceReviewItemModel> getEvidenceDetail({
    required EvidenceReviewType type,
    required String id,
  });

  /// POST /evidence-review/:type/:id/approve
  Future<void> approveEvidence({
    required EvidenceReviewType type,
    required String id,
    String? comment,
  });

  /// POST /evidence-review/:type/:id/reject
  Future<void> rejectEvidence({
    required EvidenceReviewType type,
    required String id,
    required String rejectionReason,
  });

  /// POST /evidence-review/bulk-approve
  Future<void> bulkApproveEvidence({
    required List<String> ids,
    required EvidenceReviewType type,
  });

  /// POST /evidence-review/bulk-reject
  Future<void> bulkRejectEvidence({
    required List<String> ids,
    required EvidenceReviewType type,
    required String rejectionReason,
  });

  // ── Camporee list ─────────────────────────────────────────────────────────

  /// GET /camporees?active=true
  Future<List<CamporeeItemModel>> listLocalCamporees({bool activeOnly = true});

  /// GET /camporees/union
  Future<List<CamporeeItemModel>> listUnionCamporees();

  // ── Camporee pending approvals ────────────────────────────────────────────

  /// GET /camporees/:camporeeId/pending
  Future<CamporeePendingApprovalsModel> getLocalCamporeePending(int camporeeId);

  /// GET /camporees/union/:camporeeId/pending
  Future<CamporeePendingApprovalsModel> getUnionCamporeePending(int camporeeId);

  // ── Club enrollment approve/reject ────────────────────────────────────────

  /// PATCH /camporees/:camporeeId/clubs/:camporeeClubId/approve
  Future<void> approveCamporeeClub({
    required int camporeeId,
    required int camporeeClubId,
    required CamporeeScope scope,
  });

  /// PATCH /camporees/:camporeeId/clubs/:camporeeClubId/reject
  Future<void> rejectCamporeeClub({
    required int camporeeId,
    required int camporeeClubId,
    required CamporeeScope scope,
    String? rejectionReason,
  });

  // ── Member enrollment approve/reject ──────────────────────────────────────

  /// PATCH /camporees/:camporeeId/members/:camporeeMemberId/approve
  Future<void> approveCamporeeMember({
    required int camporeeId,
    required int camporeeMemberId,
    required CamporeeScope scope,
  });

  /// PATCH /camporees/:camporeeId/members/:camporeeMemberId/reject
  Future<void> rejectCamporeeMember({
    required int camporeeId,
    required int camporeeMemberId,
    required CamporeeScope scope,
    String? rejectionReason,
  });

  // ── Payment approve/reject ────────────────────────────────────────────────

  /// PATCH /camporees/payments/:camporeePaymentId/approve
  Future<void> approveCamporeePayment({required String camporeePaymentId});

  /// PATCH /camporees/payments/:camporeePaymentId/reject
  Future<void> rejectCamporeePayment({
    required String camporeePaymentId,
    String? rejectionReason,
  });
}

/// Implementación de la fuente de datos remota del coordinador.
class CoordinatorRemoteDataSourceImpl implements CoordinatorRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'CoordinatorDS';

  CoordinatorRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Never _rethrow(Object e) {
    if (e is DioException) {
      final msg = _extractDioMessage(e);
      final code = e.response?.statusCode;
      if (code == 403) {
        throw AuthException(
          message: 'No tenés permiso para realizar esta acción',
          code: code,
        );
      }
      if (code == 404) {
        throw ServerException(message: 'Recurso no encontrado', code: code);
      }
      if (code == 409) {
        throw ServerException(
          message: msg.isNotEmpty
              ? msg
              : 'El recurso no está en el estado correcto',
          code: code,
        );
      }
      throw ServerException(message: msg, code: code);
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return (data['message'] ?? e.message ?? 'Error de conexion').toString();
      }
    } catch (_) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag);
    }
    return e.message ?? 'Error de conexion';
  }

  List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map && raw['data'] is List) {
      list = raw['data'] as List;
    } else {
      list = [];
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => fromJson(e))
        .toList();
  }

  bool _isOk(int? code) =>
      code == 200 || code == 201 || code == 204;

  // ── GET /admin/analytics/sla-dashboard ──────────────────────────────────────

  @override
  Future<SlaDashboardModel> getSlaDashboard() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.adminAnalytics}/sla-dashboard',
      );

      if (_isOk(response.statusCode)) {
        final data = response.data is Map
            ? response.data as Map<String, dynamic>
            : (response.data['data'] as Map<String, dynamic>? ?? {});
        return SlaDashboardModel.fromJson(data);
      }
      throw ServerException(
        message: 'Error al obtener dashboard SLA',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getSlaDashboard', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /evidence-review/pending ─────────────────────────────────────────────

  @override
  Future<List<EvidenceReviewItemModel>> getPendingEvidence({
    int page = 1,
    int limit = 20,
    EvidenceReviewType? type,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (type != null) {
        queryParams['type'] = type.apiValue;
      }

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.evidenceReview}/pending',
        queryParameters: queryParams,
      );

      if (_isOk(response.statusCode)) {
        return _parseList(response.data, EvidenceReviewItemModel.fromJson);
      }
      throw ServerException(
        message: 'Error al obtener evidencias pendientes',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getPendingEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /evidence-review/:type/:id ───────────────────────────────────────────

  @override
  Future<EvidenceReviewItemModel> getEvidenceDetail({
    required EvidenceReviewType type,
    required String id,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.evidenceReview}/${type.apiValue}/$id',
      );

      if (_isOk(response.statusCode)) {
        final data = response.data is Map
            ? response.data as Map<String, dynamic>
            : (response.data['data'] as Map<String, dynamic>);
        return EvidenceReviewItemModel.fromJson(data);
      }
      throw ServerException(
        message: 'Error al obtener detalle de evidencia',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getEvidenceDetail', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /evidence-review/:type/:id/approve ──────────────────────────────────

  @override
  Future<void> approveEvidence({
    required EvidenceReviewType type,
    required String id,
    String? comment,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (comment != null && comment.isNotEmpty) {
        body['comment'] = comment;
      }

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.evidenceReview}/${type.apiValue}/$id/approve',
        data: body,
      );

      if (_isOk(response.statusCode)) return;
      throw ServerException(
        message: 'Error al aprobar evidencia',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en approveEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /evidence-review/:type/:id/reject ───────────────────────────────────

  @override
  Future<void> rejectEvidence({
    required EvidenceReviewType type,
    required String id,
    required String rejectionReason,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.evidenceReview}/${type.apiValue}/$id/reject',
        data: {'reason': rejectionReason},
      );

      if (_isOk(response.statusCode)) return;
      throw ServerException(
        message: 'Error al rechazar evidencia',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en rejectEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /evidence-review/bulk-approve ───────────────────────────────────────

  @override
  Future<void> bulkApproveEvidence({
    required List<String> ids,
    required EvidenceReviewType type,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.evidenceReview}/bulk-approve',
        data: {'ids': ids, 'type': type.apiValue},
      );

      if (_isOk(response.statusCode)) return;
      throw ServerException(
        message: 'Error en aprobación masiva',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en bulkApproveEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /evidence-review/bulk-reject ────────────────────────────────────────

  @override
  Future<void> bulkRejectEvidence({
    required List<String> ids,
    required EvidenceReviewType type,
    required String rejectionReason,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.evidenceReview}/bulk-reject',
        data: {
          'ids': ids,
          'type': type.apiValue,
          'reason': rejectionReason,
        },
      );

      if (_isOk(response.statusCode)) return;
      throw ServerException(
        message: 'Error en rechazo masivo',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en bulkRejectEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /camporees?active=true ───────────────────────────────────────────────

  @override
  Future<List<CamporeeItemModel>> listLocalCamporees({
    bool activeOnly = true,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}',
        queryParameters: activeOnly ? {'active': 'true'} : {},
      );

      if (_isOk(response.statusCode)) {
        return _parseList(
          response.data,
          (json) =>
              CamporeeItemModel.fromJson(json, scope: CamporeeScope.local),
        );
      }
      throw ServerException(
        message: 'Error al obtener camporees',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en listLocalCamporees', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /camporees/union ─────────────────────────────────────────────────────

  @override
  Future<List<CamporeeItemModel>> listUnionCamporees() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/union',
      );

      if (_isOk(response.statusCode)) {
        return _parseList(
          response.data,
          (json) =>
              CamporeeItemModel.fromJson(json, scope: CamporeeScope.union),
        );
      }
      throw ServerException(
        message: 'Error al obtener camporees de unión',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en listUnionCamporees', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /camporees/:camporeeId/pending ───────────────────────────────────────

  @override
  Future<CamporeePendingApprovalsModel> getLocalCamporeePending(
    int camporeeId,
  ) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/$camporeeId/pending',
      );

      if (_isOk(response.statusCode)) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        return CamporeePendingApprovalsModel.fromJson(
          data,
          camporeeId: camporeeId,
        );
      }
      throw ServerException(
        message: 'Error al obtener aprobaciones pendientes',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getLocalCamporeePending', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /camporees/union/:camporeeId/pending ─────────────────────────────────

  @override
  Future<CamporeePendingApprovalsModel> getUnionCamporeePending(
    int camporeeId,
  ) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporees}/union/$camporeeId/pending',
      );

      if (_isOk(response.statusCode)) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        return CamporeePendingApprovalsModel.fromJson(
          data,
          camporeeId: camporeeId,
        );
      }
      throw ServerException(
        message: 'Error al obtener aprobaciones pendientes (unión)',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getUnionCamporeePending', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Club approve ─────────────────────────────────────────────────────────────

  @override
  Future<void> approveCamporeeClub({
    required int camporeeId,
    required int camporeeClubId,
    required CamporeeScope scope,
  }) async {
    try {
      final prefix = _scopePrefix(scope);
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.camporees}$prefix/$camporeeId/clubs/$camporeeClubId/approve',
      );

      if (_isOk(response.statusCode)) return;
      throw ServerException(
        message: 'Error al aprobar inscripción de club',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en approveCamporeeClub', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Club reject ──────────────────────────────────────────────────────────────

  @override
  Future<void> rejectCamporeeClub({
    required int camporeeId,
    required int camporeeClubId,
    required CamporeeScope scope,
    String? rejectionReason,
  }) async {
    try {
      final prefix = _scopePrefix(scope);
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.camporees}$prefix/$camporeeId/clubs/$camporeeClubId/reject',
        data: rejectionReason != null
            ? {'rejection_reason': rejectionReason}
            : <String, dynamic>{},
      );

      if (_isOk(response.statusCode)) return;
      throw ServerException(
        message: 'Error al rechazar inscripción de club',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en rejectCamporeeClub', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Member approve ───────────────────────────────────────────────────────────

  @override
  Future<void> approveCamporeeMember({
    required int camporeeId,
    required int camporeeMemberId,
    required CamporeeScope scope,
  }) async {
    try {
      final prefix = _scopePrefix(scope);
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.camporees}$prefix/$camporeeId/members/$camporeeMemberId/approve',
      );

      if (_isOk(response.statusCode)) return;
      throw ServerException(
        message: 'Error al aprobar inscripción de miembro',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en approveCamporeeMember', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Member reject ────────────────────────────────────────────────────────────

  @override
  Future<void> rejectCamporeeMember({
    required int camporeeId,
    required int camporeeMemberId,
    required CamporeeScope scope,
    String? rejectionReason,
  }) async {
    try {
      final prefix = _scopePrefix(scope);
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.camporees}$prefix/$camporeeId/members/$camporeeMemberId/reject',
        data: rejectionReason != null
            ? {'rejection_reason': rejectionReason}
            : <String, dynamic>{},
      );

      if (_isOk(response.statusCode)) return;
      throw ServerException(
        message: 'Error al rechazar inscripción de miembro',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en rejectCamporeeMember', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Payment approve ──────────────────────────────────────────────────────────

  @override
  Future<void> approveCamporeePayment({
    required String camporeePaymentId,
  }) async {
    try {
      // Payment approval route does NOT use camporeeId prefix.
      // PATCH /camporees/payments/:camporeePaymentId/approve
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.camporees}/payments/$camporeePaymentId/approve',
      );

      if (_isOk(response.statusCode)) return;
      throw ServerException(
        message: 'Error al aprobar pago',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en approveCamporeePayment', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Payment reject ───────────────────────────────────────────────────────────

  @override
  Future<void> rejectCamporeePayment({
    required String camporeePaymentId,
    String? rejectionReason,
  }) async {
    try {
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.camporees}/payments/$camporeePaymentId/reject',
        data: rejectionReason != null
            ? {'rejection_reason': rejectionReason}
            : <String, dynamic>{},
      );

      if (_isOk(response.statusCode)) return;
      throw ServerException(
        message: 'Error al rechazar pago',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en rejectCamporeePayment', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Union routes use /union as an intermediate segment.
  /// Local routes use no intermediate segment.
  ///
  /// Local: /camporees/:id/clubs/:cid/approve
  /// Union: /camporees/union/:id/clubs/:cid/approve
  String _scopePrefix(CamporeeScope scope) =>
      scope == CamporeeScope.union ? '/union' : '';
}
