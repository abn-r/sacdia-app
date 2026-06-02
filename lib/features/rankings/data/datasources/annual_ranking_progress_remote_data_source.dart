import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../providers/dio_provider.dart';
import '../models/annual_ranking_progress_model.dart';

abstract class AnnualRankingProgressRemoteDataSource {
  Future<AnnualRankingProgressModel> getAnnualRankingProgress({
    required int sectionId,
    required int yearId,
    CancelToken? cancelToken,
  });
}

class AnnualRankingProgressRemoteDataSourceImpl
    implements AnnualRankingProgressRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'AnnualRankingProgressDS';

  AnnualRankingProgressRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<AnnualRankingProgressModel> getAnnualRankingProgress({
    required int sectionId,
    required int yearId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubSections}/$sectionId/annual-ranking-progress',
        queryParameters: {'year_id': yearId},
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        final body = response.data;
        final json = body is Map && body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body as Map<String, dynamic>;

        return AnnualRankingProgressModel.fromJson(json);
      }

      throw ServerException(
        message: tr('rankings.annual_progress.errors.get_progress'),
        code: response.statusCode,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getAnnualRankingProgress', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  Never _rethrow(Object e) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        throw AuthException(
          message: _extractDioMessage(e),
          code: statusCode,
        );
      }

      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw ServerException(message: tr('common.error_network'), code: null);
      }

      throw ServerException(
        message: _extractDioMessage(e),
        code: statusCode,
      );
    }

    if (e is ServerException || e is AuthException) {
      throw e;
    }

    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        final message = data['message'];
        if (message is List) return message.join(', ');
        return (message ?? e.message ?? tr('common.error_network')).toString();
      }
    } catch (error) {
      AppLogger.w(
        'Error al parsear respuesta de error',
        tag: _tag,
        error: error,
      );
    }
    return e.message ?? tr('common.error_network');
  }
}

final annualRankingProgressRemoteDataSourceProvider =
    Provider<AnnualRankingProgressRemoteDataSource>((ref) {
  return AnnualRankingProgressRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: AppConstants.baseUrl,
  );
});
