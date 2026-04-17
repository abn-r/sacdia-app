import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/evidence_folder_repository.dart';

class DeleteEvidenceFileParams extends Equatable {
  final String evidenceId;

  const DeleteEvidenceFileParams({required this.evidenceId});

  @override
  List<Object?> get props => [evidenceId];
}

/// Caso de uso: eliminar un archivo de evidencia.
///
/// Solo requiere [evidenceId] (UUID). AnnualFolders no necesita sectionId
/// ni clubSectionId para la eliminación.
class DeleteEvidenceFile implements UseCase<void, DeleteEvidenceFileParams> {
  final EvidenceFolderRepository _repository;

  DeleteEvidenceFile(this._repository);

  @override
  Future<Either<Failure, void>> call(DeleteEvidenceFileParams params) async {
    return _repository.deleteFile(evidenceId: params.evidenceId);
  }
}
