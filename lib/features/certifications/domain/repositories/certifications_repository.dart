import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/certification.dart';
import '../entities/certification_detail.dart';
import '../entities/certification_evidence.dart';
import '../entities/certification_requirement.dart';
import '../entities/certification_requirement_component.dart';
import '../entities/user_certification.dart';
import '../entities/certification_progress.dart';

/// Repositorio de certificaciones (interfaz del dominio)
abstract class CertificationsRepository {
  /// Obtiene el catálogo completo de certificaciones.
  Future<Either<Failure, List<Certification>>> getCertifications({
    RequestCancelToken? cancelToken,
  });

  /// Obtiene el detalle de una certificación con módulos y secciones.
  Future<Either<Failure, CertificationDetail>> getCertificationDetail(
    int certificationId, {
    RequestCancelToken? cancelToken,
  });

  /// Obtiene las certificaciones en las que un usuario está inscrito.
  Future<Either<Failure, List<UserCertification>>> getUserCertifications(
    String userId, {
    RequestCancelToken? cancelToken,
  });

  /// Obtiene el progreso detallado de un usuario en una certificación.
  Future<Either<Failure, CertificationProgress>> getCertificationProgress(
    String userId,
    int certificationId, {
    RequestCancelToken? cancelToken,
  });

  /// Inscribe a un usuario en una certificación.
  Future<Either<Failure, void>> enrollCertification(
      String userId, int certificationId);

  /// Actualiza el progreso de una sección de una certificación.
  Future<Either<Failure, Map<String, dynamic>>> updateSectionProgress(
    String userId,
    int certificationId,
    int moduleId,
    int sectionId,
    bool completed,
  );

  /// Desinscribe a un usuario de una certificación.
  Future<Either<Failure, void>> unenrollCertification(
      String userId, int certificationId);

  // ── Ejecución de requisitos (Fase 5 — contrato por enrollmentId) ─────────

  /// Obtiene el estado de un requisito de la inscripción.
  Future<Either<Failure, CertificationRequirement>> getRequirement(
    String userId,
    int enrollmentId,
    int requirementId, {
    RequestCancelToken? cancelToken,
  });

  /// Guarda (o actualiza) el borrador de respuestas de un requisito.
  Future<Either<Failure, CertificationRequirement>> saveRequirementDraft(
    String userId,
    int enrollmentId,
    int requirementId,
    List<CertificationComponentDraftInput> responses,
  );

  /// Envía un requisito a revisión.
  ///
  /// [lockVersion] es el `lock_version` vigente de la inscripción, usado
  /// para control de concurrencia optimista por el backend.
  Future<Either<Failure, CertificationRequirementSubmitResult>>
      submitRequirement(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int lockVersion,
  });

  /// Solicita una URL firmada para subir evidencia de un componente
  /// FILE_EVIDENCE de un requisito.
  Future<Either<Failure, CertificationEvidenceUploadTicket>>
      presignRequirementEvidence(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int componentId,
    required String fileName,
    required String mimeType,
    required int fileSize,
  });

  /// Confirma que la evidencia fue subida a R2.
  Future<Either<Failure, CertificationEvidence>> confirmRequirementEvidence(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int evidenceId,
    String? checksumSha256,
  });

  /// Elimina (soft-delete) una evidencia de requisito.
  Future<Either<Failure, void>> deleteRequirementEvidence(
    String userId,
    int enrollmentId,
    int evidenceId,
  );

  /// Solicita una URL firmada para subir el comprobante de junta (cierre).
  Future<Either<Failure, CertificationCloseoutUploadTicket>>
      presignCloseoutEvidence(
    String userId,
    int enrollmentId, {
    required String fileName,
    required String mimeType,
    required int fileSize,
  });

  /// Confirma que el comprobante de junta fue subido a R2.
  Future<Either<Failure, CertificationCloseoutEvidence>>
      confirmCloseoutEvidence(
    String userId,
    int enrollmentId, {
    required int closeoutEvidenceId,
    String? checksumSha256,
  });

  /// Envía la inscripción a revisión final (cierre).
  Future<Either<Failure, CertificationSubmitFinalResult>> submitFinal(
    String userId,
    int enrollmentId,
  );

  /// Sube los bytes de un archivo directamente a una URL firmada de R2.
  ///
  /// Compartido por evidencia de requisito y comprobante de junta — ambos
  /// usan el mismo patrón presign → PUT directo → confirm.
  Future<Either<Failure, void>> uploadEvidenceFile({
    required String uploadUrl,
    required String filePath,
    required String mimeType,
    Map<String, String> headers = const {},
    void Function(double progress)? onProgress,
  });
}
