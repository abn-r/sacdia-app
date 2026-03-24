import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/transfer_request_model.dart';

abstract class TransferRemoteDataSource {
  Future<TransferRequestModel> createTransferRequest({
    required int toSectionId,
    String? reason,
  });

  Future<List<TransferRequestModel>> getMyTransferRequests();

  Future<TransferRequestModel> getTransferRequest(int requestId);
}

class TransferRemoteDataSourceImpl implements TransferRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'TransferDS';

  TransferRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  Future<String> _getAuthToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) throw AuthException(message: 'No hay sesión activa');
    return token;
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
      };

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
      final token = await _getAuthToken();

      final data = <String, dynamic>{'to_section_id': toSectionId};
      if (reason != null && reason.isNotEmpty) data['reason'] = reason;

      final response = await _dio.post(
        '$_baseUrl/requests/transfers',
        data: data,
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return TransferRequestModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: 'Error al crear solicitud de traslado',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en createTransferRequest', tag: _tag, error: e);
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message ?? 'Error de red')
          : (e.message ?? 'Error de red');
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
  Future<List<TransferRequestModel>> getMyTransferRequests() async {
    try {
      AppLogger.i('Obteniendo solicitudes de traslado', tag: _tag);
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/requests/transfers',
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final list = _unwrapList(response.data);
        return list.map(TransferRequestModel.fromJson).toList();
      }

      throw ServerException(
        message: 'Error al obtener solicitudes',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en getMyTransferRequests', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? 'Error de red',
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
  Future<TransferRequestModel> getTransferRequest(int requestId) async {
    try {
      AppLogger.i('Obteniendo detalle de solicitud $requestId', tag: _tag);
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/requests/transfers/$requestId',
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return TransferRequestModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: 'Error al obtener solicitud de traslado',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en getTransferRequest', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? 'Error de red',
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
