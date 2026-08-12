import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/certification_model.dart';
import '../models/certification_detail_model.dart';
import '../models/certification_evidence_model.dart';
import '../models/certification_requirement_model.dart';
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

  // ── Ejecución de requisitos (Fase 5 — contrato por enrollmentId) ─────────

  /// Obtiene el estado de un requisito de la inscripción.
  /// GET /certifications/users/:userId/certification-enrollments/:enrollmentId/requirements/:requirementId
  Future<CertificationRequirementModel> getRequirement(
    String userId,
    int enrollmentId,
    int requirementId, {
    CancelToken? cancelToken,
  });

  /// Guarda el borrador de respuestas de un requisito.
  /// PATCH .../requirements/:requirementId/draft
  Future<CertificationRequirementModel> saveDraft(
    String userId,
    int enrollmentId,
    int requirementId,
    List<Map<String, dynamic>> responses,
  );

  /// Envía un requisito a revisión.
  /// POST .../requirements/:requirementId/submit
  Future<CertificationRequirementSubmitResultModel> submitRequirement(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int lockVersion,
  });

  /// Solicita URL firmada para subir evidencia de un requisito.
  /// POST .../requirements/:requirementId/evidences/presign
  Future<CertificationEvidenceUploadTicketModel> presignEvidence(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int componentId,
    required String fileName,
    required String mimeType,
    required int fileSize,
  });

  /// Confirma que la evidencia fue subida a R2.
  /// POST .../requirements/:requirementId/evidences/confirm
  Future<CertificationEvidenceModel> confirmEvidence(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int evidenceId,
    String? checksumSha256,
  });

  /// Elimina (soft-delete) una evidencia.
  /// DELETE /certifications/users/:userId/certification-enrollments/:enrollmentId/evidences/:evidenceId
  Future<void> deleteEvidence(String userId, int enrollmentId, int evidenceId);

  /// Solicita URL firmada para subir el comprobante de junta.
  /// POST .../closeout-evidence/presign
  Future<CertificationCloseoutUploadTicketModel> presignCloseoutEvidence(
    String userId,
    int enrollmentId, {
    required String fileName,
    required String mimeType,
    required int fileSize,
  });

  /// Confirma que el comprobante de junta fue subido a R2.
  /// POST .../closeout-evidence/confirm
  Future<CertificationCloseoutEvidenceModel> confirmCloseoutEvidence(
    String userId,
    int enrollmentId, {
    required int closeoutEvidenceId,
    String? checksumSha256,
  });

  /// Envía la inscripción a revisión final.
  /// POST .../submit-final
  Future<CertificationSubmitFinalResultModel> submitFinal(
    String userId,
    int enrollmentId,
  );

  /// Sube los bytes de un archivo directamente a una URL firmada de R2
  /// (sin base URL ni interceptores de autenticación del backend SACDIA).
  Future<void> uploadEvidenceFile({
    required String uploadUrl,
    required String filePath,
    required String mimeType,
    Map<String, String> headers = const {},
    void Function(double progress)? onProgress,
  });
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
        return (data['message'] ?? e.message ?? tr('common.error_network'))
            .toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? tr('common.error_network');
  }

  /// Extrae el código de error de negocio (`code`) del cuerpo de la
  /// respuesta, cuando el backend lo incluye junto al `message` genérico
  /// (p.ej. `CERT_REQUIREMENT_LOCKED`, `CERT_EVIDENCE_TOO_LARGE`).
  String? _extractDioCode(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) return data['code']?.toString();
    } catch (e) {
      AppLogger.w('Error al parsear código de error', tag: _tag, error: e);
    }
    return null;
  }

  /// Mapea un [DioException] a [ServerException] usando el mensaje
  /// localizado correspondiente cuando el `code` es uno de los `CERT_*`
  /// conocidos; en caso contrario delega en [_rethrow].
  Never _rethrowCertError(DioException e) {
    if (e.type != DioExceptionType.cancel) {
      final code = _extractDioCode(e);
      final message = _certErrorMessage(code);
      if (message != null) {
        throw ServerException(message: message, code: e.response?.statusCode);
      }
    }
    _rethrow(e);
  }

  String? _certErrorMessage(String? code) {
    switch (code) {
      case 'CERT_ENROLLMENT_NOT_FOUND':
        return tr('certifications.errors.cert_enrollment_not_found');
      case 'CERT_SECTION_INVALID':
        return tr('certifications.errors.cert_section_invalid');
      case 'CERT_REQUIREMENT_LOCKED':
        return tr('certifications.errors.cert_requirement_locked');
      case 'CERT_REQUIREMENT_INCOMPLETE':
        return tr('certifications.errors.cert_requirement_incomplete');
      case 'CERT_INVALID_TRANSITION':
        return tr('certifications.errors.cert_invalid_transition');
      case 'CERT_EVIDENCE_INVALID_TYPE':
        return tr('certifications.errors.cert_evidence_invalid_type');
      case 'CERT_EVIDENCE_TOO_LARGE':
        return tr('certifications.errors.cert_evidence_too_large');
      case 'CERT_CLOSEOUT_INCOMPLETE':
        return tr('certifications.errors.cert_closeout_incomplete');
      case 'CERT_CONCURRENT_UPDATE':
        return tr('certifications.errors.cert_concurrent_update');
      default:
        return null;
    }
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
  Future<void> unenrollCertification(String userId, int certificationId) async {
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

  // ── Ejecución de requisitos (Fase 5 — contrato por enrollmentId) ─────────

  String _enrollmentBase(String userId, int enrollmentId) =>
      '$_baseUrl${ApiEndpoints.certifications}/users/$userId/certification-enrollments/$enrollmentId';

  // ── GET .../requirements/:requirementId ──────────────────────────────────

  @override
  Future<CertificationRequirementModel> getRequirement(
    String userId,
    int enrollmentId,
    int requirementId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '${_enrollmentBase(userId, enrollmentId)}/requirements/$requirementId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return CertificationRequirementModel.fromJson(
          (data['data'] ?? data) as Map<String, dynamic>,
        );
      }

      throw ServerException(
          message: tr('certifications.errors.get_requirement'),
          code: response.statusCode);
    } on DioException catch (e) {
      AppLogger.e('Error en getRequirement', tag: _tag, error: e);
      _rethrowCertError(e);
    } catch (e) {
      AppLogger.e('Error en getRequirement', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── PATCH .../requirements/:requirementId/draft ──────────────────────────

  @override
  Future<CertificationRequirementModel> saveDraft(
    String userId,
    int enrollmentId,
    int requirementId,
    List<Map<String, dynamic>> responses,
  ) async {
    try {
      final response = await _dio.patch(
        '${_enrollmentBase(userId, enrollmentId)}/requirements/$requirementId/draft',
        data: {'responses': responses},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return CertificationRequirementModel.fromJson(
          (data['data'] ?? data) as Map<String, dynamic>,
        );
      }

      throw ServerException(
          message: tr('certifications.errors.save_draft'),
          code: response.statusCode);
    } on DioException catch (e) {
      AppLogger.e('Error en saveDraft', tag: _tag, error: e);
      _rethrowCertError(e);
    } catch (e) {
      AppLogger.e('Error en saveDraft', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST .../requirements/:requirementId/submit ──────────────────────────

  @override
  Future<CertificationRequirementSubmitResultModel> submitRequirement(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int lockVersion,
  }) async {
    try {
      final response = await _dio.post(
        '${_enrollmentBase(userId, enrollmentId)}/requirements/$requirementId/submit',
        data: {'lock_version': lockVersion},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return CertificationRequirementSubmitResultModel.fromJson(
          (data['data'] ?? data) as Map<String, dynamic>,
        );
      }

      throw ServerException(
          message: tr('certifications.errors.submit_requirement'),
          code: response.statusCode);
    } on DioException catch (e) {
      AppLogger.e('Error en submitRequirement', tag: _tag, error: e);
      _rethrowCertError(e);
    } catch (e) {
      AppLogger.e('Error en submitRequirement', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST .../requirements/:requirementId/evidences/presign ───────────────

  @override
  Future<CertificationEvidenceUploadTicketModel> presignEvidence(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int componentId,
    required String fileName,
    required String mimeType,
    required int fileSize,
  }) async {
    try {
      final response = await _dio.post(
        '${_enrollmentBase(userId, enrollmentId)}/requirements/$requirementId/evidences/presign',
        data: {
          'component_id': componentId,
          'file_name': fileName,
          'mime_type': mimeType,
          'file_size': fileSize,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return CertificationEvidenceUploadTicketModel.fromJson(
          (data['data'] ?? data) as Map<String, dynamic>,
        );
      }

      throw ServerException(
          message: tr('certifications.errors.presign_evidence'),
          code: response.statusCode);
    } on DioException catch (e) {
      AppLogger.e('Error en presignEvidence', tag: _tag, error: e);
      _rethrowCertError(e);
    } catch (e) {
      AppLogger.e('Error en presignEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST .../requirements/:requirementId/evidences/confirm ───────────────

  @override
  Future<CertificationEvidenceModel> confirmEvidence(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int evidenceId,
    String? checksumSha256,
  }) async {
    try {
      final response = await _dio.post(
        '${_enrollmentBase(userId, enrollmentId)}/requirements/$requirementId/evidences/confirm',
        data: {
          'evidence_id': evidenceId,
          if (checksumSha256 != null) 'checksum_sha256': checksumSha256,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return CertificationEvidenceModel.fromJson(
          (data['data'] ?? data) as Map<String, dynamic>,
        );
      }

      throw ServerException(
          message: tr('certifications.errors.confirm_evidence'),
          code: response.statusCode);
    } on DioException catch (e) {
      AppLogger.e('Error en confirmEvidence', tag: _tag, error: e);
      _rethrowCertError(e);
    } catch (e) {
      AppLogger.e('Error en confirmEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE .../evidences/:evidenceId ─────────────────────────────────────

  @override
  Future<void> deleteEvidence(
      String userId, int enrollmentId, int evidenceId) async {
    try {
      final response = await _dio.delete(
        '${_enrollmentBase(userId, enrollmentId)}/evidences/$evidenceId',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
          message: tr('certifications.errors.delete_evidence'),
          code: response.statusCode);
    } on DioException catch (e) {
      AppLogger.e('Error en deleteEvidence', tag: _tag, error: e);
      _rethrowCertError(e);
    } catch (e) {
      AppLogger.e('Error en deleteEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST .../closeout-evidence/presign ──────────────────────────────────

  @override
  Future<CertificationCloseoutUploadTicketModel> presignCloseoutEvidence(
    String userId,
    int enrollmentId, {
    required String fileName,
    required String mimeType,
    required int fileSize,
  }) async {
    try {
      final response = await _dio.post(
        '${_enrollmentBase(userId, enrollmentId)}/closeout-evidence/presign',
        data: {
          'file_name': fileName,
          'mime_type': mimeType,
          'file_size': fileSize,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return CertificationCloseoutUploadTicketModel.fromJson(
          (data['data'] ?? data) as Map<String, dynamic>,
        );
      }

      throw ServerException(
          message: tr('certifications.errors.presign_closeout_evidence'),
          code: response.statusCode);
    } on DioException catch (e) {
      AppLogger.e('Error en presignCloseoutEvidence', tag: _tag, error: e);
      _rethrowCertError(e);
    } catch (e) {
      AppLogger.e('Error en presignCloseoutEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST .../closeout-evidence/confirm ───────────────────────────────────

  @override
  Future<CertificationCloseoutEvidenceModel> confirmCloseoutEvidence(
    String userId,
    int enrollmentId, {
    required int closeoutEvidenceId,
    String? checksumSha256,
  }) async {
    try {
      final response = await _dio.post(
        '${_enrollmentBase(userId, enrollmentId)}/closeout-evidence/confirm',
        data: {
          'closeout_evidence_id': closeoutEvidenceId,
          if (checksumSha256 != null) 'checksum_sha256': checksumSha256,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return CertificationCloseoutEvidenceModel.fromJson(
          (data['data'] ?? data) as Map<String, dynamic>,
        );
      }

      throw ServerException(
          message: tr('certifications.errors.confirm_closeout_evidence'),
          code: response.statusCode);
    } on DioException catch (e) {
      AppLogger.e('Error en confirmCloseoutEvidence', tag: _tag, error: e);
      _rethrowCertError(e);
    } catch (e) {
      AppLogger.e('Error en confirmCloseoutEvidence', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST .../submit-final ────────────────────────────────────────────────

  @override
  Future<CertificationSubmitFinalResultModel> submitFinal(
    String userId,
    int enrollmentId,
  ) async {
    try {
      final response = await _dio.post(
        '${_enrollmentBase(userId, enrollmentId)}/submit-final',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return CertificationSubmitFinalResultModel.fromJson(
          (data['data'] ?? data) as Map<String, dynamic>,
        );
      }

      throw ServerException(
          message: tr('certifications.errors.submit_final'),
          code: response.statusCode);
    } on DioException catch (e) {
      AppLogger.e('Error en submitFinal', tag: _tag, error: e);
      _rethrowCertError(e);
    } catch (e) {
      AppLogger.e('Error en submitFinal', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── PUT directo a URL firmada de R2 ──────────────────────────────────────

  @override
  Future<void> uploadEvidenceFile({
    required String uploadUrl,
    required String filePath,
    required String mimeType,
    Map<String, String> headers = const {},
    void Function(double progress)? onProgress,
  }) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      // Plain Dio instance — deliberately NOT the app's configured [_dio]:
      // the upload target is a signed R2 URL, not the SACDIA API, so it
      // must not carry the API base URL, auth Bearer token, or refresh
      // interceptors.
      final uploadDio = Dio();
      await uploadDio.put<void>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': mimeType,
            'Content-Length': bytes.length.toString(),
            ...headers,
          },
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
    } catch (e) {
      AppLogger.e('Error al subir archivo a R2', tag: _tag, error: e);
      if (e is DioException) {
        throw ServerException(
          message: _extractDioMessage(e),
          code: e.response?.statusCode,
        );
      }
      throw ServerException(message: e.toString());
    }
  }
}
