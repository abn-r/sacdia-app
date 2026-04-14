import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../entities/evidence_folder.dart';
import '../entities/evidence_file.dart';

/// Contrato del repositorio de Carpeta de Evidencias.
///
/// Todas las operaciones devuelven [Either<Failure, T>] para manejar
/// errores de forma funcional sin excepciones sin tratar.
abstract class EvidenceFolderRepository {
  /// Obtiene la carpeta de evidencias de una sección de club.
  ///
  /// Retorna `Right(null)` cuando la carpeta aún no fue creada (estado de
  /// negocio válido). Retorna `Left(Failure)` solo para errores reales.
  Future<Either<Failure, EvidenceFolder?>> getEvidenceFolder(
      String clubSectionId,
      {CancelToken? cancelToken});

  /// Envía la carpeta completa a validación.
  ///
  /// AnnualFolders opera sobre carpeta completa, no por sección.
  /// [folderId] es el UUID de annual_folder_id.
  Future<Either<Failure, void>> submitFolder(String folderId);

  /// Envía una sección individual a validación.
  ///
  /// [folderId] es el UUID de annual_folder_id.
  /// [sectionId] es el UUID de la sección dentro de la carpeta anual.
  Future<Either<Failure, void>> submitSection({
    required String folderId,
    required String sectionId,
  });

  /// Sube un archivo de evidencia a la sección especificada.
  ///
  /// [folderId] es el UUID de annual_folder_id (necesario para la URL).
  /// [sectionId] es el UUID de la sección dentro de la carpeta anual.
  /// [filePath] es la ruta local del archivo en el dispositivo.
  /// [fileName] es el nombre de archivo a usar en Storage.
  /// [mimeType] se usa para determinar si es imagen o PDF.
  Future<Either<Failure, EvidenceFile>> uploadFile({
    required String folderId,
    required String sectionId,
    required String filePath,
    required String fileName,
    required String mimeType,
    String? notes,
    void Function(double)? onProgress,
  });

  /// Elimina un archivo de evidencia.
  ///
  /// Solo requiere [evidenceId] (UUID). AnnualFolders no necesita sectionId
  /// ni clubSectionId para la eliminación.
  Future<Either<Failure, void>> deleteFile({required String evidenceId});
}
