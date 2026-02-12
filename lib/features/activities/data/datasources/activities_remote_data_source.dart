import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/activity_model.dart';
import '../models/attendance_model.dart';

/// Interfaz para la fuente de datos remota de actividades
abstract class ActivitiesRemoteDataSource {
  /// Obtiene las actividades de un club
  Future<List<ActivityModel>> getClubActivities(int clubId);

  /// Obtiene el detalle de una actividad
  Future<ActivityModel> getActivityById(int activityId);

  /// Crea una nueva actividad
  Future<ActivityModel> createActivity({
    required int clubId,
    required String title,
    String? description,
    required int activityType,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    required String instanceType,
    required int instanceId,
  });

  /// Actualiza una actividad existente
  Future<ActivityModel> updateActivity({
    required int activityId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    bool? active,
  });

  /// Elimina (desactiva) una actividad
  Future<void> deleteActivity(int activityId);

  /// Obtiene la asistencia de una actividad
  Future<List<AttendanceModel>> getActivityAttendance(int activityId);

  /// Registra la asistencia de usuarios a una actividad
  Future<int> registerAttendance(int activityId, List<String> userIds);
}

/// Implementación de la fuente de datos remota de actividades
class ActivitiesRemoteDataSourceImpl implements ActivitiesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  ActivitiesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  /// Obtiene el token de autenticación
  Future<String> _getAuthToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) {
      throw AuthException(message: 'No hay sesión activa');
    }
    return token;
  }

  @override
  Future<List<ActivityModel>> getClubActivities(int clubId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/clubs/$clubId/activities',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((activityJson) =>
                ActivityModel.fromJson(activityJson as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener actividades',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener actividades: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ActivityModel> getActivityById(int activityId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/activities/$activityId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ActivityModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al obtener actividad',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener actividad: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<AttendanceModel>> getActivityAttendance(int activityId) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/activities/$activityId/attendance',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((attendanceJson) =>
                AttendanceModel.fromJson(attendanceJson as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener asistencia',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al obtener asistencia: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ActivityModel> createActivity({
    required int clubId,
    required String title,
    String? description,
    required int activityType,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    required String instanceType,
    required int instanceId,
  }) async {
    try {
      log('📅 [ActivitiesDataSource] Creando actividad: $title');
      final token = await _getAuthToken();

      final response = await _dio.post(
        '$_baseUrl/clubs/$clubId/activities',
        data: {
          'title': title,
          'description': description,
          'activity_type': activityType,
          'start_date': startDate.toUtc().toIso8601String(),
          'end_date': endDate.toUtc().toIso8601String(),
          'location': location,
          'instance_type': instanceType,
          'instance_id': instanceId,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        log('✅ [ActivitiesDataSource] Actividad creada exitosamente');
        return ActivityModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al crear actividad',
        code: response.statusCode,
      );
    } catch (e) {
      log('❌ [ActivitiesDataSource] Error al crear actividad: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ActivityModel> updateActivity({
    required int activityId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    bool? active,
  }) async {
    try {
      log('📅 [ActivitiesDataSource] Actualizando actividad: $activityId');
      final token = await _getAuthToken();

      // Solo incluir campos que se quieren actualizar
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (startDate != null) data['start_date'] = startDate.toUtc().toIso8601String();
      if (endDate != null) data['end_date'] = endDate.toUtc().toIso8601String();
      if (location != null) data['location'] = location;
      if (active != null) data['active'] = active;

      final response = await _dio.patch(
        '$_baseUrl/activities/$activityId',
        data: data,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        log('✅ [ActivitiesDataSource] Actividad actualizada exitosamente');
        final activityData = response.data['activity'] ?? response.data;
        return ActivityModel.fromJson(activityData as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al actualizar actividad',
        code: response.statusCode,
      );
    } catch (e) {
      log('❌ [ActivitiesDataSource] Error al actualizar actividad: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteActivity(int activityId) async {
    try {
      log('📅 [ActivitiesDataSource] Eliminando actividad: $activityId');
      final token = await _getAuthToken();

      final response = await _dio.delete(
        '$_baseUrl/activities/$activityId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        log('✅ [ActivitiesDataSource] Actividad eliminada exitosamente');
        return;
      }

      throw ServerException(
        message: 'Error al eliminar actividad',
        code: response.statusCode,
      );
    } catch (e) {
      log('❌ [ActivitiesDataSource] Error al eliminar actividad: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<int> registerAttendance(int activityId, List<String> userIds) async {
    try {
      log('📅 [ActivitiesDataSource] Registrando asistencia para ${userIds.length} usuarios');
      final token = await _getAuthToken();

      final response = await _dio.post(
        '$_baseUrl/activities/$activityId/attendance',
        data: {
          'user_ids': userIds,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final recordedCount = response.data['recorded_count'] as int? ?? userIds.length;
        log('✅ [ActivitiesDataSource] Asistencia registrada: $recordedCount usuarios');
        return recordedCount;
      }

      throw ServerException(
        message: 'Error al registrar asistencia',
        code: response.statusCode,
      );
    } catch (e) {
      log('❌ [ActivitiesDataSource] Error al registrar asistencia: $e');
      if (e is DioException) {
        throw ServerException(
          message: e.response?.data?['message'] ?? e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}
