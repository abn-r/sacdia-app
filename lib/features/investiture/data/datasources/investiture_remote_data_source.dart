import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/investiture_pending_model.dart';
import '../models/investiture_history_entry_model.dart';

/// Interfaz para la fuente de datos remota de investidura.
abstract class InvestitureRemoteDataSource {
  /// POST /api/v1/enrollments/:enrollmentId/submit-for-validation
  Future<void> submitForValidation({
    required int enrollmentId,
    required int clubId,
    String? comments,
  });

  /// POST /api/v1/enrollments/:enrollmentId/validate
  Future<void> validateEnrollment({
    required int enrollmentId,
    required String action,
    String? comments,
  });

  /// POST /api/v1/enrollments/:enrollmentId/investiture
  Future<void> markAsInvestido({
    required int enrollmentId,
    String? comments,
  });

  /// GET /api/v1/investiture/pending
  Future<List<InvestiturePendingModel>> getPendingInvestitures({
    int? localFieldId,
    int? ecclesiasticalYearId,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  });

  /// GET /api/v1/enrollments/:enrollmentId/investiture-history
  Future<List<InvestitureHistoryEntryModel>> getInvestitureHistory({
    required int enrollmentId,
    CancelToken? cancelToken,
  });
}

/// Implementación de la fuente de datos remota de investidura.
class InvestitureRemoteDataSourceImpl implements InvestitureRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'InvestitureDS';

  InvestitureRemoteDataSourceImpl({
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
          message: tr('investiture.errors.no_permission'),
          code: code,
        );
      }
      if (code == 409) {
        throw ServerException(
          message: msg.isNotEmpty ? msg : tr('investiture.errors.invalid_state'),
          code: code,
        );
      }
      if (code == 404) {
        throw ServerException(
          message: tr('investiture.errors.enrollment_not_found'),
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
        return (data['message'] ?? e.message ?? tr('common.error_network')).toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? tr('common.error_network');
  }

  // ── POST /api/v1/enrollments/:enrollmentId/submit-for-validation ─────────────

  @override
  Future<void> submitForValidation({
    required int enrollmentId,
    required int clubId,
    String? comments,
  }) async {
    try {
      final body = <String, dynamic>{'club_id': clubId};
      if (comments != null && comments.isNotEmpty) {
        body['comments'] = comments;
      }

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.enrollments}/$enrollmentId/submit-for-validation',
        data: body,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
        message: tr('investiture.errors.submit_for_validation'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en submitForValidation', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /api/v1/enrollments/:enrollmentId/validate ─────────────────────────

  @override
  Future<void> validateEnrollment({
    required int enrollmentId,
    required String action,
    String? comments,
  }) async {
    try {
      final body = <String, dynamic>{'action': action};
      if (comments != null && comments.isNotEmpty) {
        body['comments'] = comments;
      }

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.enrollments}/$enrollmentId/validate',
        data: body,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
        message: tr('investiture.errors.validate_enrollment'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en validateEnrollment', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /api/v1/enrollments/:enrollmentId/investiture ──────────────────────

  @override
  Future<void> markAsInvestido({
    required int enrollmentId,
    String? comments,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (comments != null && comments.isNotEmpty) {
        body['comments'] = comments;
      }

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.enrollments}/$enrollmentId/investiture',
        data: body,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
        message: tr('investiture.errors.mark_as_investido'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en markAsInvestido', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/investiture/pending ─────────────────────────────────────────

  @override
  Future<List<InvestiturePendingModel>> getPendingInvestitures({
    int? localFieldId,
    int? ecclesiasticalYearId,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (localFieldId != null) {
        queryParams['local_field_id'] = localFieldId;
      }
      if (ecclesiasticalYearId != null) {
        queryParams['ecclesiastical_year_id'] = ecclesiasticalYearId;
      }

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.investiture}/pending',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // El backend puede devolver { data: [...], total: N } o directamente [...]
        final raw = response.data;
        final List<dynamic> list;
        if (raw is List) {
          list = raw;
        } else if (raw is Map && raw['data'] is List) {
          list = raw['data'] as List;
        } else {
          list = [];
        }
        return list
            .map((json) =>
                InvestiturePendingModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('investiture.errors.get_pending'),
        code: response.statusCode,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getPendingInvestitures', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/enrollments/:enrollmentId/investiture-history ───────────────

  @override
  Future<List<InvestitureHistoryEntryModel>> getInvestitureHistory({
    required int enrollmentId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.enrollments}/$enrollmentId/investiture-history',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data is List
            ? response.data as List
            : ((response.data as Map)['data'] as List? ?? []);
        return data
            .map((json) => InvestitureHistoryEntryModel.fromJson(
                json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('investiture.errors.get_history'),
        code: response.statusCode,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getInvestitureHistory', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
