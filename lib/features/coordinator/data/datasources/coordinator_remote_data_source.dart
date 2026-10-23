import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/evidence_review_item.dart';
import '../models/consent_pending_page_model.dart';
import '../models/coordinator_club_model.dart';
import '../models/coordinator_scope_model.dart';
import '../models/sla_dashboard_model.dart';
import '../models/evidence_review_model.dart';

/// Interfaz para la fuente de datos remota del coordinador.
abstract class CoordinatorRemoteDataSource {
  /// GET /coordination/me/scope
  Future<CoordinatorScopeModel> getMyScope({CancelToken? cancelToken});

  /// GET /coordination/me/consent-pending?limit=&offset=
  Future<ConsentPendingPageModel> getConsentPending({
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  });

  /// Lista los clubs agrupando las secciones de /coordination/me/scope.
  Future<List<CoordinatorClubModel>> listClubs({
    int? localFieldId,
    CancelToken? cancelToken,
  });

  /// GET /admin/analytics/sla-dashboard
  Future<SlaDashboardModel> getSlaDashboard({CancelToken? cancelToken});

  /// GET /evidence-review/pending?page=1&limit=20&type=class|honor
  Future<EvidenceReviewPageModel> getPendingEvidence({
    int page = 1,
    int limit = kPendingEvidencePageSize,
    EvidenceReviewType? type,
    CancelToken? cancelToken,
  });

  /// GET /evidence-review/:type/:id
  Future<EvidenceReviewItemModel> getEvidenceDetail({
    required EvidenceReviewType type,
    required String id,
    CancelToken? cancelToken,
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
      if (e.type == DioExceptionType.cancel) throw e;
      final msg = _extractDioMessage(e);
      final code = e.response?.statusCode;
      // Código de negocio (`GUARD_CLUB_SCOPE_REQUIRED`, ...): la UI decide por
      // él, nunca por el mensaje. `details` no se lee.
      final data = e.response?.data;
      final errorCode = data is Map ? data['code']?.toString() : null;
      if (code == 403) {
        throw AuthException(
          message: 'No tienes permiso para realizar esta acción',
          code: code,
          errorCode: errorCode,
        );
      }
      if (code == 404) {
        throw ServerException(
          message: 'Recurso no encontrado',
          code: code,
          errorCode: errorCode,
        );
      }
      if (code == 409) {
        throw ServerException(
          message:
              msg.isNotEmpty ? msg : 'El recurso no está en el estado correcto',
          code: code,
          errorCode: errorCode,
        );
      }
      throw ServerException(message: msg, code: code, errorCode: errorCode);
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return (data['message'] ?? e.message ?? tr('common.error_network'))
            .toString();
      }
    } catch (_) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag);
    }
    return e.message ?? tr('common.error_network');
  }

  bool _isOk(int? code) => code == 200 || code == 201 || code == 204;

  // ── GET /coordination/me/scope ─────────────────────────────────────────────

  @override
  Future<CoordinatorScopeModel> getMyScope({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.coordination}/me/scope',
        cancelToken: cancelToken,
      );

      if (_isOk(response.statusCode)) {
        final raw = response.data;
        final data = raw is Map
            ? raw['data'] is Map
                ? Map<String, dynamic>.from(raw['data'] as Map)
                : Map<String, dynamic>.from(raw)
            : <String, dynamic>{};

        return CoordinatorScopeModel.fromJson(data);
      }
      throw ServerException(
        message: tr('coordinator.errors.fetch_scope'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getMyScope (coordinator)', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /coordination/me/consent-pending ───────────────────────────────────

  @override
  Future<ConsentPendingPageModel> getConsentPending({
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.coordination}/me/consent-pending',
        queryParameters: {'limit': limit, 'offset': offset},
        cancelToken: cancelToken,
      );

      if (_isOk(response.statusCode)) {
        final raw = response.data;
        final data = raw is Map
            ? raw['data'] is Map
                ? Map<String, dynamic>.from(raw['data'] as Map)
                : Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        return ConsentPendingPageModel.fromJson(data);
      }
      throw ServerException(
        message: tr('coordinator.errors.fetch_consent_pending'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getConsentPending (coordinator)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /coordination/me/scope → clubs agrupados ───────────────────────────

  @override
  Future<List<CoordinatorClubModel>> listClubs({
    int? localFieldId,
    CancelToken? cancelToken,
  }) async {
    try {
      AppLogger.i(
        'Listando clubs para coordinador desde scope efectivo',
        tag: _tag,
      );
      final scope = await getMyScope(cancelToken: cancelToken);
      return CoordinatorClubModel.fromSections(scope.sections);
    } catch (e) {
      AppLogger.e('Error en listClubs (coordinator)', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /admin/analytics/sla-dashboard ──────────────────────────────────────

  @override
  Future<SlaDashboardModel> getSlaDashboard({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.adminAnalytics}/sla-dashboard',
        cancelToken: cancelToken,
      );

      if (_isOk(response.statusCode)) {
        // El backend responde `{ status, data: SlaDashboardDto }`; sin
        // desempaquetar, todos los KPIs quedaban en 0.
        final raw = response.data;
        final data = raw is Map<String, dynamic>
            ? (raw['data'] is Map<String, dynamic>
                ? raw['data'] as Map<String, dynamic>
                : raw)
            : const <String, dynamic>{};
        return SlaDashboardModel.fromJson(data);
      }
      throw ServerException(
        message: tr('coordinator.errors.fetch_sla_dashboard'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getSlaDashboard', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /evidence-review/pending ─────────────────────────────────────────────

  @override
  Future<EvidenceReviewPageModel> getPendingEvidence({
    int page = 1,
    int limit = kPendingEvidencePageSize,
    EvidenceReviewType? type,
    CancelToken? cancelToken,
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
        cancelToken: cancelToken,
      );

      if (_isOk(response.statusCode)) {
        return EvidenceReviewPageModel.fromResponse(
          response.data,
          page: page,
          limit: limit,
        );
      }
      throw ServerException(
        message: tr('coordinator.errors.fetch_pending_evidence'),
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
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.evidenceReview}/${type.apiValue}/$id',
        cancelToken: cancelToken,
      );

      if (_isOk(response.statusCode)) {
        final raw = response.data;
        final data = raw is Map<String, dynamic> && raw['data'] is Map
            ? Map<String, dynamic>.from(raw['data'] as Map)
            : Map<String, dynamic>.from(raw as Map);
        return EvidenceReviewItemModel.fromJson(data);
      }
      throw ServerException(
        message: tr('coordinator.errors.fetch_evidence_detail'),
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
        message: tr('coordinator.errors.approve_evidence'),
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
        message: tr('coordinator.errors.reject_evidence'),
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
        message: tr('coordinator.errors.bulk_approve_evidence'),
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
        message: tr('coordinator.errors.bulk_reject_evidence'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en bulkRejectEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
