import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/validation.dart';
import '../models/validation_model.dart';

abstract class ValidationRemoteDataSource {
  Future<ValidationSubmitResultModel> submitForReview({
    required ValidationEntityType entityType,
    required int entityId,
  });

  Future<List<ValidationHistoryEntryModel>> getValidationHistory({
    required ValidationEntityType entityType,
    required int entityId,
  });

  Future<EligibilityResultModel> checkEligibility({required String userId});
}

class ValidationRemoteDataSourceImpl implements ValidationRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'ValidationDS';

  ValidationRemoteDataSourceImpl({
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
    if (body is List) {
      return body.cast<Map<String, dynamic>>();
    }
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  @override
  Future<ValidationSubmitResultModel> submitForReview({
    required ValidationEntityType entityType,
    required int entityId,
  }) async {
    try {
      AppLogger.i('Enviando a revisión: ${entityType.slug}/$entityId', tag: _tag);
      final token = await _getAuthToken();

      final response = await _dio.post(
        '$_baseUrl/validation/submit',
        data: {
          'entity_type': entityType.slug,
          'entity_id': entityId,
        },
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ValidationSubmitResultModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: 'Error al enviar a revisión',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en submitForReview', tag: _tag, error: e);
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message ?? 'Error de red')
          : (e.message ?? 'Error de red');
      throw ServerException(message: msg.toString(), code: e.response?.statusCode);
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en submitForReview', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ValidationHistoryEntryModel>> getValidationHistory({
    required ValidationEntityType entityType,
    required int entityId,
  }) async {
    try {
      AppLogger.i(
          'Obteniendo historial de validación: ${entityType.slug}/$entityId',
          tag: _tag);
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/validation/${entityType.slug}/$entityId/history',
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final list = _unwrapList(response.data);
        return list.map(ValidationHistoryEntryModel.fromJson).toList();
      }

      throw ServerException(
        message: 'Error al obtener historial',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en getValidationHistory', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? 'Error de red',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getValidationHistory',
          tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<EligibilityResultModel> checkEligibility(
      {required String userId}) async {
    try {
      AppLogger.i('Verificando elegibilidad para usuario $userId', tag: _tag);
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/validation/eligibility/$userId',
        options: Options(headers: _authHeaders(token)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return EligibilityResultModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: 'Error al verificar elegibilidad',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en checkEligibility', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? 'Error de red',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en checkEligibility', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }
}
