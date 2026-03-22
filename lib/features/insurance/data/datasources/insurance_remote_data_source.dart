import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/member_insurance.dart';
import '../models/member_insurance_model.dart';

/// Interfaz de la fuente de datos remota para el módulo de seguros.
abstract class InsuranceRemoteDataSource {
  /// Obtiene todos los miembros del club con su estado de seguro.
  Future<List<MemberInsuranceModel>> getMembersInsurance({
    required int clubId,
    required int sectionId,
  });

  /// Obtiene el detalle del seguro de un miembro.
  Future<MemberInsuranceModel> getMemberInsuranceDetail({
    required String memberId,
  });

  /// Crea un nuevo registro de seguro para un miembro.
  Future<MemberInsuranceModel> createInsurance({
    required String memberId,
    required InsuranceType insuranceType,
    required DateTime startDate,
    required DateTime endDate,
    String? policyNumber,
    String? providerName,
    double? coverageAmount,
    String? evidenceFilePath,
    String? evidenceFileName,
    String? evidenceMimeType,
  });

  /// Actualiza un registro de seguro existente.
  Future<MemberInsuranceModel> updateInsurance({
    required int insuranceId,
    InsuranceType? insuranceType,
    DateTime? startDate,
    DateTime? endDate,
    String? policyNumber,
    String? providerName,
    double? coverageAmount,
    String? evidenceFilePath,
    String? evidenceFileName,
    String? evidenceMimeType,
  });

  /// Obtiene seguros que vencen pronto (en los próximos [days] días).
  ///
  /// Endpoint: GET /api/v1/insurance/expiring?days=30
  Future<List<MemberInsuranceModel>> getExpiringInsurance({int days = 30});
}

/// Implementación de la fuente de datos remota para seguros.
///
/// Endpoints utilizados (pendientes de implementación en backend):
/// - GET  /clubs/:clubId/sections/:sectionId/members/insurance
/// - GET  /insurance/:insuranceId  (o /users/:userId/insurance)
/// - POST /users/:userId/insurance
/// - PATCH /insurance/:insuranceId
///
/// La evidencia (imagen/PDF) se sube como multipart/form-data al crear/actualizar.
class InsuranceRemoteDataSourceImpl implements InsuranceRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'InsuranceDS';

  InsuranceRemoteDataSourceImpl({
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

  // ── GET /clubs/:clubId/sections/:sectionId/members/insurance ────────

  @override
  Future<List<MemberInsuranceModel>> getMembersInsurance({
    required int clubId,
    required int sectionId,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl/clubs/$clubId/sections/$sectionId/members/insurance',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final List<dynamic> rawList = body is List
            ? body
            : (body as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
        return rawList
            .map((e) =>
                MemberInsuranceModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener los seguros del club',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getMembersInsurance', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /users/:userId/insurance ─────────────────────────────────────────────

  @override
  Future<MemberInsuranceModel> getMemberInsuranceDetail({
    required String memberId,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl/users/$memberId/insurance',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return MemberInsuranceModel.fromDetailJson(json);
      }

      throw ServerException(
        message: 'Error al obtener el detalle del seguro',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getMemberInsuranceDetail', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /users/:userId/insurance ────────────────────────────────────────────

  @override
  Future<MemberInsuranceModel> createInsurance({
    required String memberId,
    required InsuranceType insuranceType,
    required DateTime startDate,
    required DateTime endDate,
    String? policyNumber,
    String? providerName,
    double? coverageAmount,
    String? evidenceFilePath,
    String? evidenceFileName,
    String? evidenceMimeType,
  }) async {
    try {
      final token = await _getAuthToken();

      final dynamic requestData;

      if (evidenceFilePath != null &&
          evidenceFilePath.isNotEmpty &&
          evidenceFileName != null) {
        // Multipart con archivo de evidencia
        final formFields = <String, dynamic>{
          'insurance_type': insuranceType.apiValue,
          'start_date': _formatDate(startDate),
          'end_date': _formatDate(endDate),
          if (policyNumber != null && policyNumber.isNotEmpty)
            'policy_number': policyNumber,
          if (providerName != null && providerName.isNotEmpty)
            'provider': providerName,
          if (coverageAmount != null) 'coverage_amount': coverageAmount,
          'evidence': await MultipartFile.fromFile(
            evidenceFilePath,
            filename: evidenceFileName,
            contentType: DioMediaType.parse(
                evidenceMimeType ?? 'application/octet-stream'),
          ),
        };
        requestData = FormData.fromMap(formFields);
      } else {
        // JSON sin archivo
        requestData = <String, dynamic>{
          'insurance_type': insuranceType.apiValue,
          'start_date': _formatDate(startDate),
          'end_date': _formatDate(endDate),
          if (policyNumber != null && policyNumber.isNotEmpty)
            'policy_number': policyNumber,
          if (providerName != null && providerName.isNotEmpty)
            'provider': providerName,
          if (coverageAmount != null) 'coverage_amount': coverageAmount,
        };
      }

      final response = await _dio.post(
        '$_baseUrl/users/$memberId/insurance',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            if (requestData is! FormData)
              'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            AppLogger.d(
              'Upload progress: ${(sent / total * 100).toStringAsFixed(1)}%',
              tag: _tag,
            );
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return MemberInsuranceModel.fromDetailJson(json);
      }

      throw ServerException(
        message: 'Error al registrar el seguro',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en createInsurance', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── PATCH /insurance/:insuranceId ─────────────────────────────────────────────

  @override
  Future<MemberInsuranceModel> updateInsurance({
    required int insuranceId,
    InsuranceType? insuranceType,
    DateTime? startDate,
    DateTime? endDate,
    String? policyNumber,
    String? providerName,
    double? coverageAmount,
    String? evidenceFilePath,
    String? evidenceFileName,
    String? evidenceMimeType,
  }) async {
    try {
      final token = await _getAuthToken();

      final dynamic requestData;

      if (evidenceFilePath != null &&
          evidenceFilePath.isNotEmpty &&
          evidenceFileName != null) {
        final formFields = <String, dynamic>{
          if (insuranceType != null) 'insurance_type': insuranceType.apiValue,
          if (startDate != null) 'start_date': _formatDate(startDate),
          if (endDate != null) 'end_date': _formatDate(endDate),
          if (policyNumber != null) 'policy_number': policyNumber,
          if (providerName != null) 'provider': providerName,
          if (coverageAmount != null) 'coverage_amount': coverageAmount,
          'evidence': await MultipartFile.fromFile(
            evidenceFilePath,
            filename: evidenceFileName,
            contentType: DioMediaType.parse(
                evidenceMimeType ?? 'application/octet-stream'),
          ),
        };
        requestData = FormData.fromMap(formFields);
      } else {
        requestData = <String, dynamic>{
          if (insuranceType != null) 'insurance_type': insuranceType.apiValue,
          if (startDate != null) 'start_date': _formatDate(startDate),
          if (endDate != null) 'end_date': _formatDate(endDate),
          if (policyNumber != null) 'policy_number': policyNumber,
          if (providerName != null) 'provider': providerName,
          if (coverageAmount != null) 'coverage_amount': coverageAmount,
        };
      }

      final response = await _dio.patch(
        '$_baseUrl/insurance/$insuranceId',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            AppLogger.d(
              'Upload progress: ${(sent / total * 100).toStringAsFixed(1)}%',
              tag: _tag,
            );
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return MemberInsuranceModel.fromDetailJson(json);
      }

      throw ServerException(
        message: 'Error al actualizar el seguro',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en updateInsurance', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/insurance/expiring ────────────────────────────────────────────

  @override
  Future<List<MemberInsuranceModel>> getExpiringInsurance({
    int days = 30,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl/insurance/expiring',
        queryParameters: {'days': days},
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final List<dynamic> rawList = body is List
            ? body
            : (body as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
        return rawList
            .map((e) =>
                MemberInsuranceModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener seguros por vencer',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getExpiringInsurance', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
