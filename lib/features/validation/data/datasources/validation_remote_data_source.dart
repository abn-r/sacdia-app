import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
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
    CancelToken? cancelToken,
  });

  Future<EligibilityResultModel> checkEligibility({
    required String userId,
    CancelToken? cancelToken,
  });
}

class ValidationRemoteDataSourceImpl implements ValidationRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'ValidationDS';

  ValidationRemoteDataSourceImpl({
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
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.validation}/submit',
        data: {
          'entity_type': entityType.slug,
          'entity_id': entityId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ValidationSubmitResultModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: tr('validation.errors.submit_for_review'),
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en submitForReview', tag: _tag, error: e);
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message ?? tr('common.error_network'))
          : (e.message ?? tr('common.error_network'));
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
    CancelToken? cancelToken,
  }) async {
    try {
      AppLogger.i(
          'Obteniendo historial de validación: ${entityType.slug}/$entityId',
          tag: _tag);
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.validation}/${entityType.slug}/$entityId/history',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final list = _unwrapList(response.data);
        return list.map(ValidationHistoryEntryModel.fromJson).toList();
      }

      throw ServerException(
        message: tr('validation.errors.get_history'),
        code: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('DioException en getValidationHistory', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? tr('common.error_network'),
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
  Future<EligibilityResultModel> checkEligibility({
    required String userId,
    CancelToken? cancelToken,
  }) async {
    try {
      AppLogger.i('Verificando elegibilidad para usuario $userId', tag: _tag);
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.validation}/eligibility/$userId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return EligibilityResultModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: tr('validation.errors.check_eligibility'),
        code: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('DioException en checkEligibility', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? tr('common.error_network'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en checkEligibility', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }
}
