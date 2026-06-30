import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/evidence_folder.dart';
import '../repositories/evidence_folder_repository.dart';

class CreateEvidenceFolderParams extends Equatable {
  final String clubSectionId;

  const CreateEvidenceFolderParams({required this.clubSectionId});

  @override
  List<Object?> get props => [clubSectionId];
}

/// Caso de uso: inicializar la Carpeta Anual de Evidencias de una sección.
///
/// La app usa el ID entero de la sección activa; el backend resuelve la
/// inscripción anual y la plantilla publicada correspondiente.
class CreateEvidenceFolder
    implements UseCase<EvidenceFolder, CreateEvidenceFolderParams> {
  final EvidenceFolderRepository _repository;

  CreateEvidenceFolder(this._repository);

  @override
  Future<Either<Failure, EvidenceFolder>> call(
    CreateEvidenceFolderParams params,
  ) async {
    return _repository.createEvidenceFolder(params.clubSectionId);
  }
}
