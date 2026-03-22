import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/dashboard_summary_model.dart';

/// Interfaz para la fuente de datos remota del dashboard
abstract class DashboardRemoteDataSource {
  /// Obtiene el resumen del dashboard del usuario autenticado
  Future<DashboardSummaryModel> getDashboardSummary();
}

/// Implementación de la fuente de datos remota del dashboard
///
/// Endpoint: GET /api/v1/dashboard/summary
class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'DashboardDS';

  DashboardRemoteDataSourceImpl({
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

  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<DashboardSummaryModel> getDashboardSummary() async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl/dashboard/summary',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final json = body is Map<String, dynamic>
            ? (body.containsKey('data')
                ? body['data'] as Map<String, dynamic>
                : body)
            : body as Map<String, dynamic>;
        return DashboardSummaryModel.fromJson(json);
      }

      throw ServerException(
        message: 'Error al obtener el resumen del dashboard',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getDashboardSummary', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Never _rethrow(Object e) {
    if (e is DioException) {
      final msg = _extractDioMessage(e);
      throw ServerException(message: msg, code: e.response?.statusCode);
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return (data['message'] ?? e.message ?? 'Error de conexión').toString();
      }
    } catch (_) {}
    return e.message ?? 'Error de conexión';
  }
}
