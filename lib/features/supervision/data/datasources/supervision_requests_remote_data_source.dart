import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/business_error.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/supervision_request.dart';
import '../models/supervision_request_model.dart';

abstract class SupervisionRequestsRemoteDataSource {
  /// GET /requests/{transfers|assignments}?status=
  Future<List<SupervisionRequestModel>> getRequests({
    required SupervisionRequestKind kind,
    required SupervisionRequestStatus status,
    CancelToken? cancelToken,
  });

  /// POST /requests/{transfers|assignments}/:id/review
  Future<SupervisionRequestModel> review({
    required SupervisionRequestKind kind,
    required String requestId,
    required bool approve,
    String? comment,
  });
}

class SupervisionRequestsRemoteDataSourceImpl
    implements SupervisionRequestsRemoteDataSource {
  SupervisionRequestsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'SupervisionRequestsDS';

  String _path(SupervisionRequestKind kind) =>
      '$_baseUrl${ApiEndpoints.requests}/'
      '${kind == SupervisionRequestKind.transfer ? 'transfers' : 'assignments'}';

  bool _isOk(int? code) => code == 200 || code == 201;

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      if (isAuthorizationStale(e)) throw authorizationStaleException(e);
      // Only `code` and `message` are read; never `details`.
      final mapped =
          businessErrorFrom(e, fallbackMessage: tr('common.error_network'));
      throw mapped;
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  @override
  Future<List<SupervisionRequestModel>> getRequests({
    required SupervisionRequestKind kind,
    required SupervisionRequestStatus status,
    CancelToken? cancelToken,
  }) async {
    try {
      final apiStatus = status.apiValue;
      final response = await _dio.get(
        _path(kind),
        queryParameters: apiStatus == null ? null : {'status': apiStatus},
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) {
        throw ServerException(
          message: tr('common.error_network'),
          code: response.statusCode,
        );
      }
      final raw = response.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List
              ? raw['data'] as List
              : const []);
      final parse = kind == SupervisionRequestKind.transfer
          ? SupervisionRequestModel.fromTransferJson
          : SupervisionRequestModel.fromAssignmentJson;
      return [
        for (final item in list)
          if (item is Map) parse(item),
      ].where((r) => r.id.isNotEmpty).toList();
    } catch (e) {
      AppLogger.e('Error en getRequests (supervision)', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionRequestModel> review({
    required SupervisionRequestKind kind,
    required String requestId,
    required bool approve,
    String? comment,
  }) async {
    try {
      final body = <String, dynamic>{
        'action': approve ? 'approved' : 'rejected',
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      };
      final response = await _dio.post(
        '${_path(kind)}/$requestId/review',
        data: body,
      );
      if (!_isOk(response.statusCode)) {
        throw ServerException(
          message: tr('common.error_network'),
          code: response.statusCode,
        );
      }
      final raw = response.data;
      final data =
          raw is Map ? (raw['data'] is Map ? raw['data'] as Map : raw) : null;
      if (data == null) {
        throw ServerException(
          message: tr('common.error_network'),
          code: response.statusCode,
        );
      }
      return kind == SupervisionRequestKind.transfer
          ? SupervisionRequestModel.fromTransferJson(data)
          : SupervisionRequestModel.fromAssignmentJson(data);
    } catch (e) {
      AppLogger.e('Error en review (supervision)', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
