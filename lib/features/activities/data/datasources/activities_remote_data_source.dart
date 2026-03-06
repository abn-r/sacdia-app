import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/activity_model.dart';
import '../models/attendance_model.dart';
import '../models/create_activity_request.dart';

/// Interfaz para la fuente de datos remota de actividades
abstract class ActivitiesRemoteDataSource {
  Future<List<ActivityModel>> getClubActivities(
    int clubId, {
    int? clubTypeId,
    int? activityTypeId,
  });
  Future<ActivityModel> getActivityById(int activityId);
  Future<ActivityModel> createActivity({
    required int clubId,
    required CreateActivityRequest request,
  });
  Future<ActivityModel> updateActivity({
    required int activityId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    bool? active,
  });
  Future<void> deleteActivity(int activityId);
  Future<List<AttendanceModel>> getActivityAttendance(int activityId);
  Future<int> registerAttendance(int activityId, List<String> userIds);
}

/// Implementación de la fuente de datos remota de actividades
class ActivitiesRemoteDataSourceImpl implements ActivitiesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'ActivitiesDS';

  ActivitiesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  Future<String> _getAuthToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) {
      throw AuthException(message: 'No hay sesión activa');
    }
    return token;
  }

  @override
  Future<List<ActivityModel>> getClubActivities(
    int clubId, {
    int? clubTypeId,
    int? activityTypeId,
  }) async {
    try {
      final token = await _getAuthToken();
      final queryParams = <String, dynamic>{'active': 'true'};
      if (clubTypeId != null) queryParams['clubTypeId'] = clubTypeId;
      if (activityTypeId != null) queryParams['activityTypeId'] = activityTypeId;

      final response = await _dio.get(
        '$_baseUrl/clubs/$clubId/activities',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.data as Map<String, dynamic>;
        final List<dynamic> data = responseBody['data'] as List<dynamic>;
        return data
            .map((json) => ActivityModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: 'Error al obtener actividades', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getClubActivities', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
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
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ActivityModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(message: 'Error al obtener actividad', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getActivityById', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
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
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => AttendanceModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(message: 'Error al obtener asistencia', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getActivityAttendance', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(message: e.message ?? 'Error de conexión', code: e.response?.statusCode);
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ActivityModel> createActivity({
    required int clubId,
    required CreateActivityRequest request,
  }) async {
    try {
      AppLogger.i('Creando actividad: ${request.name}', tag: _tag);
      final token = await _getAuthToken();

      final response = await _dio.post(
        '$_baseUrl/clubs/$clubId/activities',
        data: request.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        // El backend puede devolver { data: {...} } o directamente el objeto
        final activityData = responseData is Map<String, dynamic> &&
                responseData.containsKey('data')
            ? responseData['data'] as Map<String, dynamic>
            : responseData as Map<String, dynamic>;
        return ActivityModel.fromJson(activityData);
      }

      throw ServerException(message: 'Error al crear actividad', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en createActivity', tag: _tag, error: e);
      if (e is DioException) {
        final message = e.response?.data is Map
            ? (e.response!.data['message'] ?? e.message ?? 'Error de conexión')
            : (e.message ?? 'Error de conexión');
        throw ServerException(
          message: message.toString(),
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
      AppLogger.i('Actualizando actividad: $activityId', tag: _tag);
      final token = await _getAuthToken();

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
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final activityData = response.data['activity'] ?? response.data;
        return ActivityModel.fromJson(activityData as Map<String, dynamic>);
      }

      throw ServerException(message: 'Error al actualizar actividad', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en updateActivity', tag: _tag, error: e);
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
      AppLogger.i('Eliminando actividad: $activityId', tag: _tag);
      final token = await _getAuthToken();

      final response = await _dio.delete(
        '$_baseUrl/activities/$activityId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) return;

      throw ServerException(message: 'Error al eliminar actividad', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en deleteActivity', tag: _tag, error: e);
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
      AppLogger.i('Registrando asistencia: ${userIds.length} usuarios', tag: _tag);
      final token = await _getAuthToken();

      final response = await _dio.post(
        '$_baseUrl/activities/$activityId/attendance',
        data: {'user_ids': userIds},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final recordedCount = response.data['recorded_count'] as int? ?? userIds.length;
        AppLogger.i('Asistencia registrada: $recordedCount usuarios', tag: _tag);
        return recordedCount;
      }

      throw ServerException(message: 'Error al registrar asistencia', code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en registerAttendance', tag: _tag, error: e);
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
