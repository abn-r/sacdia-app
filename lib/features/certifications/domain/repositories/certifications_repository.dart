import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/certification.dart';
import '../entities/certification_detail.dart';
import '../entities/user_certification.dart';
import '../entities/certification_progress.dart';

/// Repositorio de certificaciones (interfaz del dominio)
abstract class CertificationsRepository {
  /// Obtiene el catálogo completo de certificaciones.
  Future<Either<Failure, List<Certification>>> getCertifications();

  /// Obtiene el detalle de una certificación con módulos y secciones.
  Future<Either<Failure, CertificationDetail>> getCertificationDetail(
      int certificationId);

  /// Obtiene las certificaciones en las que un usuario está inscrito.
  Future<Either<Failure, List<UserCertification>>> getUserCertifications(
      String userId);

  /// Obtiene el progreso detallado de un usuario en una certificación.
  Future<Either<Failure, CertificationProgress>> getCertificationProgress(
      String userId, int certificationId);

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
}
