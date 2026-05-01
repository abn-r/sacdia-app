import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/certification_model.dart';
import '../models/certification_detail_model.dart';
import '../models/user_certification_model.dart';
import '../models/certification_progress_model.dart';

/// Interfaz para la fuente de datos remota de certificaciones
abstract class CertificationsRemoteDataSource {
  /// Obtiene el catálogo completo de certificaciones.
  /// GET /certifications/certifications
  Future<List<CertificationModel>> getCertifications({
    CancelToken? cancelToken,
  });

  /// Obtiene el detalle de una certificación con módulos y secciones.
  /// GET /certifications/certifications/:id
  Future<CertificationDetailModel> getCertificationDetail(
    int certificationId, {
    CancelToken? cancelToken,
  });

  /// Obtiene las certificaciones en las que un usuario está inscrito.
  /// GET /certifications/users/:userId/certifications
  Future<List<UserCertificationModel>> getUserCertifications(
    String userId, {
    CancelToken? cancelToken,
  });

  /// Obtiene el progreso detallado de un usuario en una certificación.
  /// GET /certifications/users/:userId/certifications/:certificationId/progress
  Future<CertificationProgressModel> getCertificationProgress(
    String userId,
    int certificationId, {
    CancelToken? cancelToken,
  });

  /// Inscribe a un usuario en una certificación.
  /// POST /certifications/users/:userId/certifications/enroll
  Future<void> enrollCertification(String userId, int certificationId);

  /// Actualiza el progreso de una sección de una certificación.
  /// PATCH /certifications/users/:userId/certifications/:certificationId/progress
  Future<Map<String, dynamic>> updateSectionProgress(
    String userId,
    int certificationId,
    int moduleId,
    int sectionId,
    bool completed,
  );

  /// Desinscribe a un usuario de una certificación.
  /// DELETE /certifications/users/:userId/certifications/:certificationId
  Future<void> unenrollCertification(String userId, int certificationId);
}

/// Implementación de la fuente de datos remota de certificaciones.
///
/// Utiliza Dio para llamadas REST al backend SACDIA.
/// Auth token se lee desde [FlutterSecureStorage].
class CertificationsRemoteDataSourceImpl
    implements CertificationsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'CertificationsDS';

  CertificationsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
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
        return (data['message'] ?? e.message ?? tr('common.error_network')).toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? tr('common.error_network');
  }

  // ── GET /certifications/certifications ──────────────────────────────────────

  @override
  Future<List<CertificationModel>> getCertifications({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.certifications}/certifications',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) =>
                CertificationModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: tr('certifications.errors.get_certifications'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getCertifications', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /certifications/certifications/:id ──────────────────────────────────

  @override
  Future<CertificationDetailModel> getCertificationDetail(
    int certificationId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.certifications}/certifications/$certificationId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CertificationDetailModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: tr('certifications.errors.get_certification_detail'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getCertificationDetail', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /certifications/users/:userId/certifications ────────────────────────

  @override
  Future<List<UserCertificationModel>> getUserCertifications(
    String userId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.certifications}/users/$userId/certifications',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) =>
                UserCertificationModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: tr('certifications.errors.get_user_certifications'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getUserCertifications', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /certifications/users/:userId/certifications/:certificationId/progress

  @override
  Future<CertificationProgressModel> getCertificationProgress(
    String userId,
    int certificationId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.certifications}/users/$userId/certifications/$certificationId/progress',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CertificationProgressModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: tr('certifications.errors.get_certification_progress'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getCertificationProgress', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /certifications/users/:userId/certifications/enroll ────────────────

  @override
  Future<void> enrollCertification(String userId, int certificationId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.certifications}/users/$userId/certifications/enroll',
        data: {'certification_id': certificationId},
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
          message: tr('certifications.errors.enroll_certification'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en enrollCertification', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── PATCH /certifications/users/:userId/certifications/:certificationId/progress

  @override
  Future<Map<String, dynamic>> updateSectionProgress(
    String userId,
    int certificationId,
    int moduleId,
    int sectionId,
    bool completed,
  ) async {
    try {
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.certifications}/users/$userId/certifications/$certificationId/progress',
        data: {
          'module_id': moduleId,
          'section_id': sectionId,
          'completed': completed,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }

      throw ServerException(
          message: tr('certifications.errors.update_section_progress'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en updateSectionProgress', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /certifications/users/:userId/certifications/:certificationId ─────

  @override
  Future<void> unenrollCertification(
      String userId, int certificationId) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.certifications}/users/$userId/certifications/$certificationId',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
          message: tr('certifications.errors.unenroll_certification'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en unenrollCertification', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
