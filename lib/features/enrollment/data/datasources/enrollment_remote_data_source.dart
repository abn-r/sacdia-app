import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/enrollment.dart';
import '../models/enrollment_model.dart';

/// Interfaz de la fuente de datos remota de inscripciones.
abstract class EnrollmentRemoteDataSource {
  Future<EnrollmentModel> createEnrollment({
    required String clubId,
    required int sectionId,
    required String address,
    double? lat,
    double? long,
    required List<MeetingSchedule> meetingSchedule,
    int? soulsTarget,
    bool? fee,
    double? feeAmount,
    String? directorId,
    List<String> deputyDirectorIds,
    String? secretaryId,
    String? treasurerId,
    String? secretaryTreasurerId,
  });

  Future<EnrollmentModel?> getCurrentEnrollment({
    required String clubId,
    required int sectionId,
    CancelToken? cancelToken,
  });

  Future<EnrollmentModel> updateEnrollment({
    required String clubId,
    required int sectionId,
    required String enrollmentId,
    String? address,
    double? lat,
    double? long,
    List<MeetingSchedule>? meetingSchedule,
    int? soulsTarget,
    bool? fee,
    double? feeAmount,
    String? directorId,
    List<String>? deputyDirectorIds,
    String? secretaryId,
    String? treasurerId,
    String? secretaryTreasurerId,
  });
}

/// Implementación de [EnrollmentRemoteDataSource] usando Dio.
class EnrollmentRemoteDataSourceImpl implements EnrollmentRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'EnrollmentDS';

  EnrollmentRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Map<String, dynamic> _unwrapMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) {
        if (body['data'] == null) return {};
        if (body['data'] is Map<String, dynamic>) {
          return body['data'] as Map<String, dynamic>;
        }
      }
      return body;
    }
    return {};
  }

  /// Construye el payload para crear/actualizar una inscripción.
  ///
  /// meeting_schedule se serializa como JSON string para backward compatibility
  /// con el backend actual que espera meeting_days como String.
  /// Cuando el backend actualice el DTO, se puede enviar directo como lista.
  Map<String, dynamic> _buildPayload({
    required String address,
    double? lat,
    double? long,
    required List<MeetingSchedule> meetingSchedule,
    int? soulsTarget,
    bool? fee,
    double? feeAmount,
    String? directorId,
    List<String>? deputyDirectorIds,
    String? secretaryId,
    String? treasurerId,
    String? secretaryTreasurerId,
  }) {
    final daysList = meetingSchedule.map((s) => s.day).toList();
    final scheduleJson = meetingSchedule.map((s) => s.toJson()).toList();

    return {
      'address': address,
      // Legacy field: plain day names for current backend
      'meeting_days': daysList.join(', '),
      // Extended field: structured schedule (ignored by current backend, ready for upgrade)
      'meeting_schedule': jsonEncode(scheduleJson),
      if (lat != null) 'lat': lat,
      if (long != null) 'long': long,
      if (soulsTarget != null) 'souls_target': soulsTarget,
      if (fee != null) 'fee': fee,
      if (feeAmount != null) 'fee_amount': feeAmount,
      if (directorId != null) 'director_id': directorId,
      if (deputyDirectorIds != null && deputyDirectorIds.isNotEmpty)
        'deputy_director_ids': deputyDirectorIds,
      if (secretaryId != null) 'secretary_id': secretaryId,
      if (treasurerId != null) 'treasurer_id': treasurerId,
      if (secretaryTreasurerId != null)
        'secretary_treasurer_id': secretaryTreasurerId,
    };
  }

  @override
  Future<EnrollmentModel> createEnrollment({
    required String clubId,
    required int sectionId,
    required String address,
    double? lat,
    double? long,
    required List<MeetingSchedule> meetingSchedule,
    int? soulsTarget,
    bool? fee,
    double? feeAmount,
    String? directorId,
    List<String> deputyDirectorIds = const [],
    String? secretaryId,
    String? treasurerId,
    String? secretaryTreasurerId,
  }) async {
    try {
      AppLogger.i('Creando inscripción en sección $sectionId', tag: _tag);

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/enrollments',
        data: _buildPayload(
          address: address,
          lat: lat,
          long: long,
          meetingSchedule: meetingSchedule,
          soulsTarget: soulsTarget,
          fee: fee,
          feeAmount: feeAmount,
          directorId: directorId,
          deputyDirectorIds: deputyDirectorIds,
          secretaryId: secretaryId,
          treasurerId: treasurerId,
          secretaryTreasurerId: secretaryTreasurerId,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return EnrollmentModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: 'Error al crear inscripción',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en createEnrollment', tag: _tag, error: e);
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message ?? 'Error de red')
          : (e.message ?? 'Error de red');
      throw ServerException(message: msg.toString(), code: e.response?.statusCode);
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en createEnrollment', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<EnrollmentModel?> getCurrentEnrollment({
    required String clubId,
    required int sectionId,
    CancelToken? cancelToken,
  }) async {
    try {
      AppLogger.i('Obteniendo inscripción activa en sección $sectionId', tag: _tag);

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/enrollments/current',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = _unwrapMap(response.data);
        if (json.isEmpty) return null;
        return EnrollmentModel.fromJson(json);
      }

      if (response.statusCode == 404) return null;

      throw ServerException(
        message: 'Error al obtener inscripción',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      if (e.response?.statusCode == 404) return null;
      AppLogger.e('DioException en getCurrentEnrollment', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ?? e.message ?? 'Error de red',
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getCurrentEnrollment', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<EnrollmentModel> updateEnrollment({
    required String clubId,
    required int sectionId,
    required String enrollmentId,
    String? address,
    double? lat,
    double? long,
    List<MeetingSchedule>? meetingSchedule,
    int? soulsTarget,
    bool? fee,
    double? feeAmount,
    String? directorId,
    List<String>? deputyDirectorIds,
    String? secretaryId,
    String? treasurerId,
    String? secretaryTreasurerId,
  }) async {
    try {
      AppLogger.i('Actualizando inscripción $enrollmentId', tag: _tag);

      final data = <String, dynamic>{};
      if (address != null) {
        data['address'] = address;
        if (lat != null) data['lat'] = lat;
        if (long != null) data['long'] = long;
      }
      if (meetingSchedule != null) {
        data['meeting_days'] =
            meetingSchedule.map((s) => s.day).join(', ');
        data['meeting_schedule'] =
            jsonEncode(meetingSchedule.map((s) => s.toJson()).toList());
      }
      if (soulsTarget != null) data['souls_target'] = soulsTarget;
      if (fee != null) data['fee'] = fee;
      if (feeAmount != null) data['fee_amount'] = feeAmount;
      if (directorId != null) data['director_id'] = directorId;
      if (deputyDirectorIds != null) data['deputy_director_ids'] = deputyDirectorIds;
      if (secretaryId != null) data['secretary_id'] = secretaryId;
      if (treasurerId != null) data['treasurer_id'] = treasurerId;
      if (secretaryTreasurerId != null) {
        data['secretary_treasurer_id'] = secretaryTreasurerId;
      }

      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/enrollments/$enrollmentId',
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return EnrollmentModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: 'Error al actualizar inscripción',
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en updateEnrollment', tag: _tag, error: e);
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message ?? 'Error de red')
          : (e.message ?? 'Error de red');
      throw ServerException(message: msg.toString(), code: e.response?.statusCode);
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en updateEnrollment', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }
}
