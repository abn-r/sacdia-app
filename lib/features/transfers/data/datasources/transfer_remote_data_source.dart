import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/transfer_request_model.dart';

abstract class TransferRemoteDataSource {
  Future<TransferRequestModel> createTransferRequest({
    required int toSectionId,
    String? reason,
  });

  Future<List<TransferRequestModel>> getMyTransferRequests({
    CancelToken? cancelToken,
  });

  Future<TransferRequestModel> getTransferRequest(
    int requestId, {
    CancelToken? cancelToken,
  });
}

class TransferRemoteDataSourceImpl implements TransferRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'TransferDS';

  TransferRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Map<String, dynamic> _unwrapMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data') && body['data'] is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>;
      }
      return body;
    }
    return {};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic body) {
    if (body is List) return body.cast<Map<String, dynamic>>();
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  @override
  Future<TransferRequestModel> createTransferRequest({
    required int toSectionId,
    String? reason,
  }) async {
    try {
      AppLogger.i('Creando solicitud de traslado a sección $toSectionId',
          tag: _tag);
      final data = <String, dynamic>{'to_section_id': toSectionId};
      if (reason != null && reason.isNotEmpty) data['reason'] = reason;

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.requests}/transfers',
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return TransferRequestModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: tr('transfers.errors.create'),
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en createTransferRequest', tag: _tag, error: e);
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message ?? tr('common.error_network'))
          : (e.message ?? tr('common.error_network'));
      throw ServerException(
          message: msg.toString(), code: e.response?.statusCode);
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en createTransferRequest',
          tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<TransferRequestModel>> getMyTransferRequests({
    CancelToken? cancelToken,
  }) async {
    try {
      AppLogger.i('Obteniendo solicitudes de traslado', tag: _tag);
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.requests}/transfers',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final list = _unwrapList(response.data);
        return list.map(TransferRequestModel.fromJson).toList();
      }

      throw ServerException(
        message: tr('transfers.errors.get_list'),
        code: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('DioException en getMyTransferRequests', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? tr('common.error_network'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getMyTransferRequests',
          tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<TransferRequestModel> getTransferRequest(
    int requestId, {
    CancelToken? cancelToken,
  }) async {
    try {
      AppLogger.i('Obteniendo detalle de solicitud $requestId', tag: _tag);
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.requests}/transfers/$requestId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return TransferRequestModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: tr('transfers.errors.get_detail'),
        code: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('DioException en getTransferRequest', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? tr('common.error_network'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getTransferRequest',
          tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }
}
