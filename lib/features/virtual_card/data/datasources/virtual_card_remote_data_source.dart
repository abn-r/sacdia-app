import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/virtual_card_model.dart';

abstract class VirtualCardRemoteDataSource {
  Future<VirtualCardModel> getVirtualCard({CancelToken? cancelToken});
}

class VirtualCardRemoteDataSourceImpl implements VirtualCardRemoteDataSource {
  VirtualCardRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'VirtualCardDS';

  @override
  Future<VirtualCardModel> getVirtualCard({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl${ApiEndpoints.qr}/me/card',
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null) {
        throw ServerException(message: tr('virtual_card.errors.empty_card'));
      }

      final payload = data['data'];
      final json = payload is Map
          ? Map<String, dynamic>.from(payload)
          : data;
      return VirtualCardModel.fromJson(Map<String, dynamic>.from(json));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      final msg = _extractMessage(e);
      AppLogger.w('Error al obtener la tarjeta virtual', tag: _tag, error: msg);
      throw ServerException(message: msg, code: e.response?.statusCode);
    } on AppException {
      rethrow;
    } catch (e) {
      AppLogger.e('Error inesperado al obtener la tarjeta virtual',
          tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? tr('common.error_network');
  }
}
