import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
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

  DashboardRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  /// Obtiene el token de autenticación
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

      // Obtener datos del usuario y sus roles
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

      final userData = meResponse.data;

      // Obtener clase actual del usuario
      Map<String, dynamic>? currentClass;
      try {
        final classResponse = await _dio.get(
          '$_baseUrl/users/$userId/classes',
          options: Options(headers: {
            'Authorization': 'Bearer $token',
          }),
        );

        if (classResponse.statusCode == 200 || classResponse.statusCode == 201) {
          final classes = classResponse.data as List<dynamic>?;
          if (classes != null && classes.isNotEmpty) {
            // Buscar la clase actual (la que está en progreso)
            currentClass = classes.firstWhere(
              (c) => c['status'] == 'in_progress',
              orElse: () => classes.first,
            ) as Map<String, dynamic>?;
          }
        }
      } catch (e) {
        log('Error al obtener clases: $e');
        // No es crítico, continuar sin datos de clase
      }

      // Obtener estadísticas de especialidades
      Map<String, dynamic>? honorsStats;
      try {
        final honorsResponse = await _dio.get(
          '$_baseUrl/users/$userId/honors/stats',
          options: Options(headers: {
            'Authorization': 'Bearer $token',
          }),
        );

        if (honorsResponse.statusCode == 200 || honorsResponse.statusCode == 201) {
          honorsStats = honorsResponse.data as Map<String, dynamic>?;
        }
      } catch (e) {
        log('Error al obtener estadísticas de especialidades: $e');
        // No es crítico, continuar sin estadísticas
      }

      // Obtener actividades próximas
      List<Map<String, dynamic>> upcomingActivities = [];
      try {
        final activitiesResponse = await _dio.get(
          '$_baseUrl/activities',
          queryParameters: {
            'limit': 3,
            'status': 'upcoming',
          },
          options: Options(headers: {
            'Authorization': 'Bearer $token',
          }),
        );

        if (activitiesResponse.statusCode == 200 || activitiesResponse.statusCode == 201) {
          final activities = activitiesResponse.data as List<dynamic>?;
          if (activities != null) {
            upcomingActivities = activities
                .map((a) => a as Map<String, dynamic>)
                .toList();
          }
        }
      } catch (e) {
        log('Error al obtener actividades: $e');
        // No es crítico, continuar sin actividades
      }

      // Construir el modelo de resumen
      final dashboardData = {
        'user_name': userData['name'] ?? 'Usuario',
        'user_avatar': userData['avatar'],
        'club_name': userData['club']?['name'],
        'club_type': userData['club']?['type'],
        'user_role': userData['roles']?.isNotEmpty == true
            ? userData['roles'][0]['name']
            : null,
        'current_class_name': currentClass?['class_name'],
        'class_progress': currentClass?['progress'] ?? 0.0,
        'honors_completed': honorsStats?['completed'] ?? 0,
        'honors_in_progress': honorsStats?['in_progress'] ?? 0,
        'upcoming_activities': upcomingActivities,
      };

      return DashboardSummaryModel.fromJson(dashboardData);
    } on DioException catch (e) {
      log('Error Dio al obtener datos del dashboard: ${e.message}');
      throw ServerException(
        message: e.response?.data?['message'] ?? 'Error al obtener datos del dashboard',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      log('Error al obtener datos del dashboard: $e');
      throw ServerException(message: e.toString());
    }
  }
}
