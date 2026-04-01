import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/notification_model.dart';

/// Tipo de retorno paginado para el historial de notificaciones.
typedef NotificationHistoryResult = ({
  List<NotificationModel> items,
  int total,
  int totalPages,
});

/// Interfaz del data source remoto de notificaciones.
abstract class NotificationsRemoteDataSource {
  /// GET /notifications/history
  Future<NotificationHistoryResult> getHistory({
    int page = 1,
    int limit = 20,
  });
}

/// Implementación del data source remoto de notificaciones.
class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'NotificationsDS';

  NotificationsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Never _rethrow(Object e) {
    if (e is DioException) {
      final msg = _extractDioMessage(e);
      final code = e.response?.statusCode;
      if (code == 403 || code == 401) {
        throw AuthException(
          message: 'No tienes permiso para ver las notificaciones',
          code: code,
        );
      }
      throw ServerException(message: msg, code: code);
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return (data['message'] ?? e.message ?? 'Error de conexion').toString();
      }
    } catch (_) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag);
    }
    return e.message ?? 'Error de conexion';
  }

  @override
  Future<NotificationHistoryResult> getHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/notifications/history',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data;

        // Backend returns { data: [...], total: N, page: N, limit: N, totalPages: N }
        final List<dynamic> dataList;
        int total = 0;
        int totalPages = 1;

        if (raw is Map) {
          dataList = (raw['data'] as List?) ?? [];
          total = (raw['total'] as num?)?.toInt() ?? dataList.length;
          totalPages = (raw['totalPages'] as num?)?.toInt() ?? 1;
        } else if (raw is List) {
          dataList = raw;
          total = dataList.length;
        } else {
          dataList = [];
        }

        final items = dataList
            .map((json) =>
                NotificationModel.fromJson(json as Map<String, dynamic>))
            .toList();

        return (items: items, total: total, totalPages: totalPages);
      }

      throw ServerException(
        message: 'Error al obtener historial de notificaciones',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getHistory', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
