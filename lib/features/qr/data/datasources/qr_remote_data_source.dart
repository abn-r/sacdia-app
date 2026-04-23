import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/qr_member_token_model.dart';

abstract class QrRemoteDataSource {
  /// GET /qr/member/token
  Future<QrMemberTokenModel> getMemberToken({CancelToken? cancelToken});
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
        throw ServerException(message: 'Respuesta vacia del servidor QR');
      }
      return QrMemberTokenModel.fromJson(data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      final msg = _extractDioMessage(e);
      AppLogger.w('Error al obtener token QR', tag: _tag, error: msg);
      throw ServerException(message: msg, code: e.response?.statusCode);
    }
  }

  String _extractDioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Error de conexion';
  }
}
