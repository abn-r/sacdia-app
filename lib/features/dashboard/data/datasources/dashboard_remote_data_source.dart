import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/dashboard_summary_model.dart';

/// Interfaz para la fuente de datos remota del dashboard
abstract class DashboardRemoteDataSource {
  /// Obtiene los datos del dashboard para un usuario
  Future<DashboardSummaryModel> getDashboardData(String userId);
}

/// Implementación de la fuente de datos remota del dashboard
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

  Future<String?> _getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  @override
  Future<DashboardSummaryModel> getDashboardData(String userId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw AuthException(message: 'No hay sesión activa');
      }

      final meResponse = await _dio.get(
        '$_baseUrl/auth/me',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (meResponse.statusCode != 200 && meResponse.statusCode != 201) {
        throw ServerException(
          message: 'Error al obtener datos del usuario',
          code: meResponse.statusCode,
        );
      }

      // /auth/me responde: { "status": "success", "data": { ... } }
      final meBody = meResponse.data as Map<String, dynamic>;
      final userData = (meBody['data'] as Map<String, dynamic>?) ?? meBody;

      final firstName = (userData['name'] as String?) ?? '';
      final paternalLn = (userData['paternal_last_name'] as String?) ?? '';
      final maternalLn = (userData['maternal_last_name'] as String?) ?? '';
      final fullName = [firstName, paternalLn, maternalLn]
          .where((s) => s.isNotEmpty)
          .join(' ');

      final rawRoles = userData['roles'] as List<dynamic>?;
      final firstRole = rawRoles?.isNotEmpty == true
          ? rawRoles!.first as String?
          : null;

      final clubData = userData['club'] as Map<String, dynamic>?;

      final dashboardData = {
        'user_name': fullName.isNotEmpty ? fullName : 'Usuario',
        'user_avatar': userData['user_image'] as String?,
        'club_name': clubData?['club_name'] as String?,
        'club_type': clubData?['club_type'] as String?,
        'user_role': firstRole,
        'current_class_name': null,
        'class_progress': 0.0,
        'honors_completed': 0,
        'honors_in_progress': 0,
        'upcoming_activities': <Map<String, dynamic>>[],
      };

      return DashboardSummaryModel.fromJson(dashboardData);
    } on DioException catch (e) {
      AppLogger.e('Error al obtener datos del dashboard', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al obtener datos del dashboard',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en dashboard', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }
}
