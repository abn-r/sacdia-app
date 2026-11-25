import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/supervision_pending_counts_model.dart';

abstract class SupervisionRemoteDataSource {
  /// GET /supervision/pending-counts
  Future<SupervisionPendingCountsModel> getPendingCounts({
    CancelToken? cancelToken,
  });
}

class SupervisionRemoteDataSourceImpl implements SupervisionRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'SupervisionDS';

  SupervisionRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      if (isAuthorizationStale(e)) throw authorizationStaleException(e);
      final code = e.response?.statusCode;
      // Only `code` and `message` are read; never `details`.
      final data = e.response?.data;
      final errorCode = data is Map ? data['code']?.toString() : null;
      if (code == 403) {
        throw AuthException(
          message: 'No tienes permiso para realizar esta acción',
          code: code,
          errorCode: errorCode,
        );
      }
      throw ServerException(
        message: _extractMessage(e),
        code: code,
        errorCode: errorCode,
      );
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return (data['message'] ?? e.message ?? tr('common.error_network'))
          .toString();
    }
    return e.message ?? tr('common.error_network');
  }

  bool _isOk(int? code) => code == 200 || code == 201;

  @override
  Future<SupervisionPendingCountsModel> getPendingCounts({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.supervision}/pending-counts',
        cancelToken: cancelToken,
      );

      if (_isOk(response.statusCode)) {
        final raw = response.data;
        final data = raw is Map
            ? raw['data'] is Map
                ? Map<String, dynamic>.from(raw['data'] as Map)
                : Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        return SupervisionPendingCountsModel.fromJson(data);
      }
      throw ServerException(
        message: tr('common.error_network'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getPendingCounts (supervision)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
