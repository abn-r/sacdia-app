import 'dart:io';

import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/activity_model.dart';
import '../models/attendance_model.dart';
import '../models/club_section_model.dart';
import '../models/create_activity_request.dart';

/// Interfaz para la fuente de datos remota de actividades
abstract class ActivitiesRemoteDataSource {
  Future<List<ActivityModel>> getClubActivities(
    int clubId, {
    int? clubTypeId,
  });
  Future<ActivityModel> getActivityById(int activityId);
  Future<ActivityModel> createActivity({
    required int clubId,
    required CreateActivityRequest request,
  });
  Future<ActivityModel> updateActivity({
    required int activityId,
    String? name,
    String? description,
    double? lat,
    double? long,
    String? activityTime,
    String? activityDate,
    String? activityEndDate,
    String? activityPlace,
    int? platform,
    int? activityTypeId,
    String? linkMeet,
    bool? active,
    Set<String> clearFields = const {},
    // TODO(backend): UpdateActivityDto does not yet support club_section_ids.
    // Once the backend PATCH /activities/:id endpoint accepts this field,
    // remove this comment and wire it through. The value is sent optimistically
    // and will be stripped by NestJS whitelist validation until then.
    List<int>? clubSectionIds,
  });
  Future<void> deleteActivity(int activityId);
  Future<List<AttendanceModel>> getActivityAttendance(int activityId);
  Future<int> registerAttendance(int activityId, List<String> userIds);

  /// Sube una imagen para la actividad y devuelve la URL firmada resultante.
  Future<String> uploadActivityImage(int activityId, File imageFile);

  /// Obtiene las secciones de un club (para el picker de actividades conjuntas).
  /// Llama a GET /api/v1/clubs/:clubId/sections
  Future<List<ClubSectionModel>> getClubSections(int clubId);
}

/// Implementación de la fuente de datos remota de actividades
class ActivitiesRemoteDataSourceImpl implements ActivitiesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'ActivitiesDS';

  ActivitiesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<List<ActivityModel>> getClubActivities(
    int clubId, {
    int? clubTypeId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'active': 'true'};
      if (clubTypeId != null) queryParams['clubTypeId'] = clubTypeId;

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/activities',
        queryParameters: queryParams,
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
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.activities}/$activityId',
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
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.activities}/$activityId/attendance',
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

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/activities',
        data: request.toJson(),
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
    String? name,
    String? description,
    double? lat,
    double? long,
    String? activityTime,
    String? activityDate,
    String? activityEndDate,
    String? activityPlace,
    int? platform,
    int? activityTypeId,
    String? linkMeet,
    bool? active,
    Set<String> clearFields = const {},
    List<int>? clubSectionIds,
  }) async {
    try {
      AppLogger.i('Actualizando actividad: $activityId', tag: _tag);

      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (lat != null) data['lat'] = lat;
      if (long != null) data['long'] = long;
      if (activityTime != null) data['activity_time'] = activityTime;
      if (activityDate != null) data['activity_date'] = activityDate;
      if (activityEndDate != null) data['activity_end_date'] = activityEndDate;
      if (activityPlace != null) data['activity_place'] = activityPlace;
      if (platform != null) data['platform'] = platform;
      if (activityTypeId != null) data['activity_type_id'] = activityTypeId;
      if (linkMeet != null) data['link_meet'] = linkMeet;
      if (active != null) data['active'] = active;

      // Campos explícitamente nulos (el backend usa undefined-check, necesitamos la clave presente)
      for (final field in clearFields) {
        data[field] = null;
      }

      // Joint activity sections — sent when provided (2+ IDs).
      // TODO(backend): stripped by NestJS whitelist until UpdateActivityDto adds club_section_ids.
      if (clubSectionIds != null && clubSectionIds.length >= 2) {
        data['club_section_ids'] = clubSectionIds;
      }

      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.activities}/$activityId',
        data: data,
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

      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.activities}/$activityId',
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

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.activities}/$activityId/attendance',
        data: {'user_ids': userIds},
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

  @override
  Future<String> uploadActivityImage(int activityId, File imageFile) async {
    try {
      AppLogger.i('Subiendo imagen para actividad: $activityId', tag: _tag);

      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.activities}/$activityId/image',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data as Map<String, dynamic>;
        final data = responseData['data'] as Map<String, dynamic>;
        final url = data['url'] as String;
        AppLogger.i('Imagen subida exitosamente para actividad: $activityId', tag: _tag);
        return url;
      }

      throw ServerException(
        message: 'Error al subir imagen de actividad',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en uploadActivityImage', tag: _tag, error: e);
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
  Future<List<ClubSectionModel>> getClubSections(int clubId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) =>
                ClubSectionModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener secciones del club',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getClubSections', tag: _tag, error: e);
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
