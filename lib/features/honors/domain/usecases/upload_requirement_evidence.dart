import 'dart:io';

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/requirement_evidence.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para subir un archivo de evidencia a un requisito de especialidad.
///
/// Soporta archivos e imágenes. Para enlaces externos usar [AddRequirementEvidenceLink].
/// Devuelve la [RequirementEvidence] creada con la URL pública del archivo subido.
class UploadRequirementEvidence
    implements UseCase<RequirementEvidence, UploadRequirementEvidenceParams> {
  final HonorsRepository repository;

  UploadRequirementEvidence(this.repository);

  @override
  Future<Either<Failure, RequirementEvidence>> call(
      UploadRequirementEvidenceParams params) async {
    return await repository.uploadRequirementEvidence(
      params.userId,
      params.honorId,
      params.requirementId,
      params.file,
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
