import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:mime/mime.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/requirement_evidence.dart';
import '../repositories/honors_repository.dart';

/// MIME types permitidos para evidencias de requisitos.
const _allowedMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
};

/// Caso de uso para subir un archivo de evidencia a un requisito de especialidad.
///
/// Soporta archivos e imágenes. Para enlaces externos usar [AddRequirementEvidenceLink].
/// Devuelve la [RequirementEvidence] creada con la URL pública del archivo subido.
/// Rechaza archivos con MIME type fuera de la lista permitida (image/jpeg, image/png,
/// image/webp, application/pdf) antes de llegar a la capa de datos.
class UploadRequirementEvidence
    implements UseCase<RequirementEvidence, UploadRequirementEvidenceParams> {
  final HonorsRepository repository;

  UploadRequirementEvidence(this.repository);

  @override
  Future<Either<Failure, RequirementEvidence>> call(
      UploadRequirementEvidenceParams params) async {
    final mimeType = lookupMimeType(params.file.path);
    if (mimeType == null || !_allowedMimeTypes.contains(mimeType)) {
      return Left(
        ValidationFailure(
          message:
              'Tipo de archivo no permitido. Usá JPG, PNG, WebP o PDF.',
        ),
      );
    }

    return await repository.uploadRequirementEvidence(
      params.userId,
      params.honorId,
      params.requirementId,
      params.file,
      mimeType: mimeType,
    );
  }
}

/// Parámetros para subir una evidencia de requisito
class UploadRequirementEvidenceParams {
  final String userId;
  final int honorId;
  final int requirementId;

  /// Archivo local a subir (imagen, PDF, etc.).
  final File file;

  const UploadRequirementEvidenceParams({
    required this.userId,
    required this.honorId,
    required this.requirementId,
    required this.file,
  });
}
