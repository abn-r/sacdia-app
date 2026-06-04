import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/user_master_honor_model.dart';

abstract class MasterHonorsRemoteDataSource {
  Future<List<UserMasterHonorModel>> getUserMasterHonors(
    String userId, {
    CancelToken? cancelToken,
  });
}

class MasterHonorsRemoteDataSourceImpl implements MasterHonorsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'MasterHonorsDS';

  MasterHonorsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<List<UserMasterHonorModel>> getUserMasterHonors(
    String userId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/master-honors',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _extractList(response.data);
        return data
            .map((json) =>
                UserMasterHonorModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'No se pudieron obtener las maestrías del usuario',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getUserMasterHonors', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
          message: e.message ?? 'Error de red',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  List<dynamic> _extractList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map<String, dynamic> && raw['data'] is List) {
      return raw['data'] as List<dynamic>;
    }
    throw ServerException(message: 'Respuesta inválida de maestrías');
  }
}
