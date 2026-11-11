import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

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
  /// El backend acepta tanto [meeting_days] legacy como el arreglo estructurado
  /// [meeting_schedule], y exige [latitude]/[longitude] como nombres canónicos.
  Map<String, dynamic> _buildPayload({
    required String address,
    double? lat,
    double? long,
    required List<MeetingSchedule> meetingSchedule,
    int? soulsTarget,
    bool? fee,
    double? feeAmount,
  }) {
    final daysList = meetingSchedule.map((s) => s.day).toList();
    final scheduleJson = meetingSchedule.map((s) => s.toJson()).toList();

    return {
      'address': address,
      // Campo legacy conservado para compatibilidad con reportes históricos.
      'meeting_days': daysList.join(', '),
      'meeting_schedule': scheduleJson,
      if (lat != null) 'latitude': lat,
      if (long != null) 'longitude': long,
      if (soulsTarget != null) 'souls_target': soulsTarget,
      if (fee != null) 'fee': fee,
      if (feeAmount != null) 'fee_amount': feeAmount,
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
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return EnrollmentModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: tr('enrollment.errors.create'),
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en createEnrollment', tag: _tag, error: e);
      final msg = _dioErrorMessage(e, 'enrollment.errors.create');
      final body = e.response?.data;
      throw ServerException(
        message: msg.toString(),
        code: e.response?.statusCode,
        errorCode: body is Map ? body['code']?.toString() : null,
      );
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
      AppLogger.i('Obteniendo inscripción activa en sección $sectionId',
          tag: _tag);

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
        message: tr('enrollment.errors.get_current'),
        code: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      if (e.response?.statusCode == 404) return null;
      // Treat 5xx as "no enrollment" — the backend may be temporarily
      // unavailable. Degrading gracefully here keeps the dashboard usable
      // while the backend issue is fixed separately.
      final statusCode = e.response?.statusCode;
      if (statusCode != null && statusCode >= 500) {
        AppLogger.w(
          'getCurrentEnrollment devolvió $statusCode — tratando como sin inscripción activa',
          tag: _tag,
          error: e,
        );
        return null;
      }
      AppLogger.e('DioException en getCurrentEnrollment', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ??
            e.message ??
            tr('common.error_network'),
        code: statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getCurrentEnrollment',
          tag: _tag, error: e);
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
  }) async {
    try {
      AppLogger.i('Actualizando inscripción $enrollmentId', tag: _tag);

      final data = <String, dynamic>{};
      if (address != null) {
        data['address'] = address;
        if (lat != null) data['latitude'] = lat;
        if (long != null) data['longitude'] = long;
      }
      if (meetingSchedule != null) {
        data['meeting_days'] = meetingSchedule.map((s) => s.day).join(', ');
        data['meeting_schedule'] =
            meetingSchedule.map((s) => s.toJson()).toList();
      }
      if (soulsTarget != null) data['souls_target'] = soulsTarget;
      if (fee != null) data['fee'] = fee;
      if (feeAmount != null) data['fee_amount'] = feeAmount;

      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/enrollments/$enrollmentId',
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return EnrollmentModel.fromJson(_unwrapMap(response.data));
      }

      throw ServerException(
        message: tr('enrollment.errors.update'),
        code: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('DioException en updateEnrollment', tag: _tag, error: e);
      final msg = _dioErrorMessage(e, 'enrollment.errors.update');
      final body = e.response?.data;
      throw ServerException(
        message: msg.toString(),
        code: e.response?.statusCode,
        errorCode: body is Map ? body['code']?.toString() : null,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en updateEnrollment', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }
}

/// Message for a failed request: the server's text when it sent one, a
/// "could not save" fallback when it answered without one, and the network
/// message only when there was no response at all.
String _dioErrorMessage(DioException e, String fallbackKey) {
  final data = e.response?.data;
  if (data is Map) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message;
    if (message is List && message.isNotEmpty) return message.join('\n');
  }
  if (e.response != null) return tr(fallbackKey);
  return e.message ?? tr('common.error_network');
}
