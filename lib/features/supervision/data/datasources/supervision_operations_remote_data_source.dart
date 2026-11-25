import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/business_error.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/supervision_operations.dart';
import '../models/supervision_operations_model.dart';

abstract class SupervisionOperationsRemoteDataSource {
  /// GET /admin/analytics/operations-dashboard
  Future<SupervisionOperationsDashboard> getDashboard(
    SupervisionOperationsQuery query, {
    CancelToken? cancelToken,
  });
}

class SupervisionOperationsRemoteDataSourceImpl
    implements SupervisionOperationsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'SupervisionOperationsDS';

  SupervisionOperationsRemoteDataSourceImpl({
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

  Object? _unwrap(Object? raw) =>
      raw is Map && raw.containsKey('data') ? raw['data'] : raw;

  @override
  Future<SupervisionOperationsDashboard> getDashboard(
    SupervisionOperationsQuery query, {
    CancelToken? cancelToken,
  }) async {
    try {
      // The server rejects unknown params, so only non-null ids are sent.
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.adminAnalytics}/operations-dashboard',
        queryParameters: {
          if (query.divisionId != null) 'division_id': query.divisionId,
          if (query.unionId != null) 'union_id': query.unionId,
          if (query.localFieldId != null) 'local_field_id': query.localFieldId,
        },
        cancelToken: cancelToken,
      );
      final code = response.statusCode;
      if (code != 200 && code != 201) {
        throw ServerException(
          message: tr('common.error_network'),
          code: code,
        );
      }
      return SupervisionOperationsModel.parseDashboard(_unwrap(response.data));
    } catch (e) {
      AppLogger.e('Error en getDashboard (supervision operations)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
