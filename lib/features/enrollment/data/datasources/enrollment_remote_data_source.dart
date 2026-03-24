import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/enrollment_model.dart';

/// Interfaz de la fuente de datos remota de inscripciones.
abstract class EnrollmentRemoteDataSource {
  Future<EnrollmentModel> createEnrollment({
    required String clubId,
    required int sectionId,
    required String address,
    required List<String> meetingDays,
  });

  Future<EnrollmentModel?> getCurrentEnrollment({
    required String clubId,
    required int sectionId,
  });

  Future<EnrollmentModel> updateEnrollment({
    required String clubId,
    required int sectionId,
    required int enrollmentId,
    String? address,
    List<String>? meetingDays,
  });
}

/// Implementación de [EnrollmentRemoteDataSource] usando Dio.
class EnrollmentRemoteDataSourceImpl implements EnrollmentRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'EnrollmentDS';

  EnrollmentRemoteDataSourceImpl({
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

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _unwrapMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data') && body['data'] is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>;
      }
      return body;
    }
    return {};
  }

  @override
  Future<EnrollmentModel> createEnrollment({
    required String clubId,
    required int sectionId,
    required String address,
    required List<String> meetingDays,
  }) async {
    try {
      AppLogger.i('Creando inscripción en sección $sectionId', tag: _tag);
      final token = await _getAuthToken();

      final response = await _dio.post(
        '$_baseUrl/clubs/$clubId/sections/$sectionId/enrollments',
        data: {
          'address': address,
          'meeting_days': meetingDays,
        },
        options: Options(headers: _authHeaders(token)),
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
  }) async {
    try {
      AppLogger.i('Obteniendo inscripción activa en sección $sectionId', tag: _tag);
      final token = await _getAuthToken();

      final response = await _dio.get(
        '$_baseUrl/clubs/$clubId/sections/$sectionId/enrollments/current',
        options: Options(headers: _authHeaders(token)),
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
      // 404 = no hay inscripción activa
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
    required int enrollmentId,
    String? address,
    List<String>? meetingDays,
  }) async {
    try {
      AppLogger.i('Actualizando inscripción $enrollmentId', tag: _tag);
      final token = await _getAuthToken();

      final data = <String, dynamic>{};
      if (address != null) data['address'] = address;
      if (meetingDays != null) data['meeting_days'] = meetingDays;

      final response = await _dio.patch(
        '$_baseUrl/clubs/$clubId/sections/$sectionId/enrollments/$enrollmentId',
        data: data,
        options: Options(headers: _authHeaders(token)),
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
