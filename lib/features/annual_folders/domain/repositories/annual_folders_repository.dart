import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/annual_folder.dart';

/// Repositorio de carpetas anuales (interfaz del dominio)
abstract class AnnualFoldersRepository {
  /// Obtiene la carpeta anual de un enrollment.
  /// GET /api/v1/annual-folders/enrollment/:enrollmentId
  Future<Either<Failure, AnnualFolder>> getFolderByEnrollment(
      int enrollmentId);

  /// Sube una evidencia a una sección de la carpeta.
  /// POST /api/v1/annual-folders/:folderId/evidences
  Future<Either<Failure, FolderEvidence>> uploadEvidence(
    int folderId, {
    required int sectionId,
    required String fileUrl,
    required String fileName,
    String? notes,
  });

  /// Elimina una evidencia.
  /// DELETE /api/v1/annual-folders/evidences/:evidenceId
  Future<Either<Failure, void>> deleteEvidence(int evidenceId);

  /// Envía la carpeta para revisión.
  /// POST /api/v1/annual-folders/:folderId/submit
  Future<Either<Failure, AnnualFolder>> submitFolder(int folderId);
}
