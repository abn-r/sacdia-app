import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/qr_member_token_model.dart';
import '../models/qr_scan_result_model.dart';

abstract class QrRemoteDataSource {
  /// GET /qr/member/token
  Future<QrMemberTokenModel> getMemberToken({CancelToken? cancelToken});

  /// POST /qr/scan
  Future<QrScanResultModel> scanToken({
    required String token,
    int? activityId,
    CancelToken? cancelToken,
  });
}

class QrRemoteDataSourceImpl implements QrRemoteDataSource {
  QrRemoteDataSourceImpl({required Dio dio, required String baseUrl})
      : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'QrDS';

  @override
  Future<QrMemberTokenModel> getMemberToken({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl${ApiEndpoints.qr}/member/token',
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) {
        throw ServerException(message: tr('qr.errors.empty_qr_response'));
      }
      return QrMemberTokenModel.fromJson(data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      final msg = _extractDioMessage(e);
      AppLogger.w('Error al obtener token QR', tag: _tag, error: msg);
      throw ServerException(message: msg, code: e.response?.statusCode);
    }
  }

  @override
  Future<QrScanResultModel> scanToken({
    required String token,
    int? activityId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl${ApiEndpoints.qr}/scan',
        data: {
          'token': token,
          if (activityId != null) 'activity_id': activityId,
        },
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) {
        throw ServerException(message: tr('qr.errors.empty_response'));
      }
      return QrScanResultModel.fromJson(data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      final msg = _extractDioMessage(e);
      AppLogger.w('Error al escanear QR', tag: _tag, error: msg);
      throw ServerException(message: msg, code: e.response?.statusCode);
    }
  }

  String _extractDioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? tr('common.error_network');
  }
}
