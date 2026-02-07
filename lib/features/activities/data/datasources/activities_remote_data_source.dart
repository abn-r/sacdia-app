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

  /// Obtiene la asistencia de una actividad
  Future<List<AttendanceModel>> getActivityAttendance(int activityId);

  /// Registra la asistencia de un usuario a una actividad
  Future<AttendanceModel> registerAttendance(int activityId, String userId, bool attended);
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
  Future<AttendanceModel> registerAttendance(
    int activityId,
    String userId,
    bool attended,
  ) async {
    try {
      final token = await _getAuthToken();

      final response = await _dio.post(
        '$_baseUrl/activities/$activityId/attendance',
        data: {
          'user_id': userId,
          'attended': attended,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AttendanceModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: 'Error al registrar asistencia',
        code: response.statusCode,
      );
    } catch (e) {
      log('Error al registrar asistencia: $e');
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
}
