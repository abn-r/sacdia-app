import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/dashboard_pending.dart';
import '../models/dashboard_pending_model.dart';

/// Fuente remota de los pendientes de gestión del inicio.
abstract class DashboardPendingRemoteDataSource {
  Future<DashboardPending> getPending({CancelToken? cancelToken});
}

/// Endpoint: GET /api/v1/dashboard/pending
///
/// La sección activa la resuelve el servidor igual que en `/dashboard/summary`
/// (mismo Dio, mismo `X-Acting-For`).
class DashboardPendingRemoteDataSourceImpl
    implements DashboardPendingRemoteDataSource {
  DashboardPendingRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'DashboardPendingDS';

  @override
  Future<DashboardPending> getPending({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.dashboard}/pending',
        cancelToken: cancelToken,
      );

      final body = response.data;
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body is Map) {
        final json = Map<String, dynamic>.from(body);
        final data = json['data'];
        return DashboardPendingModel.fromJson(
          data is Map ? Map<String, dynamic>.from(data) : json,
        );
      }

      throw ServerException(
        message: tr('dashboard.errors.get_pending'),
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.w('Error en getPending', tag: _tag, error: e);
      throw ServerException(
        message: e.message ?? tr('common.error_network'),
        code: e.response?.statusCode,
      );
    }
  }
}
