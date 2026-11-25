import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/business_error.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/supervision_enrollment.dart';
import '../models/supervision_enrollment_model.dart';

abstract class SupervisionEnrollmentsRemoteDataSource {
  /// GET /club-enrollments/validation/queue
  Future<SupervisionEnrollmentPage> getQueue({
    SupervisionEnrollmentStatus status =
        SupervisionEnrollmentStatus.pendingValidation,
    String? search,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  });

  /// POST /club-enrollments/:id/approve
  Future<SupervisionEnrollment> approve(
    String enrollmentId, {
    CancelToken? cancelToken,
  });

  /// POST /club-enrollments/:id/reject
  Future<SupervisionEnrollment> reject(
    String enrollmentId,
    String reason, {
    CancelToken? cancelToken,
  });
}

class SupervisionEnrollmentsRemoteDataSourceImpl
    implements SupervisionEnrollmentsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'SupervisionEnrollmentsDS';

  SupervisionEnrollmentsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      if (isAuthorizationStale(e)) throw authorizationStaleException(e);
      // Only `code` and `message` are read; never `details`.
      throw businessErrorFrom(e, fallbackMessage: tr('common.error_network'));
    }
    if (e is AppException) throw e;
    throw ServerException(message: e.toString());
  }

  bool _isOk(int? code) => code == 200 || code == 201;

  Object? _unwrap(Object? raw) =>
      raw is Map && raw.containsKey('data') ? raw['data'] : raw;

  SupervisionEnrollment _item(Response<dynamic> response) {
    if (_isOk(response.statusCode)) {
      final model = SupervisionEnrollmentModel.tryParse(_unwrap(response.data));
      if (model != null) return model;
    }
    throw ServerException(
      message: tr('common.error_network'),
      code: response.statusCode,
    );
  }

  @override
  Future<SupervisionEnrollmentPage> getQueue({
    SupervisionEnrollmentStatus status =
        SupervisionEnrollmentStatus.pendingValidation,
    String? search,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final trimmed = search?.trim() ?? '';
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubEnrollments}/validation/queue',
        queryParameters: {
          if (status != SupervisionEnrollmentStatus.unknown)
            'status': status.apiValue,
          if (trimmed.isNotEmpty)
            'search':
                trimmed.length > 100 ? trimmed.substring(0, 100) : trimmed,
          'page': page,
          'limit': limit,
        },
        cancelToken: cancelToken,
      );
      if (_isOk(response.statusCode)) {
        return SupervisionEnrollmentModel.parsePage(_unwrap(response.data));
      }
      throw ServerException(
        message: tr('common.error_network'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getQueue (supervision)', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionEnrollment> approve(
    String enrollmentId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubEnrollments}/$enrollmentId/approve',
        cancelToken: cancelToken,
      );
      return _item(response);
    } catch (e) {
      AppLogger.e('Error en approve (supervision)', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionEnrollment> reject(
    String enrollmentId,
    String reason, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubEnrollments}/$enrollmentId/reject',
        data: {'reason': reason},
        cancelToken: cancelToken,
      );
      return _item(response);
    } catch (e) {
      AppLogger.e('Error en reject (supervision)', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
