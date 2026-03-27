import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/evidence_folder.dart';
import '../entities/evidence_file.dart';

/// Contrato del repositorio de Carpeta de Evidencias.
///
/// Todas las operaciones devuelven [Either<Failure, T>] para manejar
/// errores de forma funcional sin excepciones sin tratar.
abstract class EvidenceFolderRepository {
  /// Obtiene la carpeta de evidencias de una sección de club.
  Future<Either<Failure, EvidenceFolder>> getEvidenceFolder(
      String clubSectionId);

  /// Envía una sección a validación (pendiente → enviado).
  Future<Either<Failure, void>> submitSection(
      String clubSectionId, String sectionId);

  /// Sube un archivo de evidencia a la sección especificada.
  ///
  /// [filePath] es la ruta local del archivo en el dispositivo.
  /// [fileName] es el nombre de archivo a usar en Storage.
  /// [mimeType] se usa para determinar si es imagen o PDF.
  Future<Either<Failure, EvidenceFile>> uploadFile({
    required String clubSectionId,
    required String sectionId,
    required String filePath,
    required String fileName,
    required String mimeType,
    void Function(double)? onProgress,
  });

  /// Elimina un archivo de evidencia (solo cuando sección está pendiente).
  Future<Either<Failure, void>> deleteFile({
    required String clubSectionId,
    required String sectionId,
    required String fileId,
  });
}
