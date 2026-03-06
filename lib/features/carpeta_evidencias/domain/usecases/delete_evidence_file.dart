import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/evidence_folder_repository.dart';

class DeleteEvidenceFileParams extends Equatable {
  final String clubInstanceId;
  final String sectionId;
  final String fileId;

  const DeleteEvidenceFileParams({
    required this.clubInstanceId,
    required this.sectionId,
    required this.fileId,
  });

  @override
  List<Object?> get props => [clubInstanceId, sectionId, fileId];
}

/// Caso de uso: eliminar un archivo de evidencia.
///
/// Solo puede ejecutarse cuando la sección está en estado pendiente.
/// La validación de negocio debe ocurrir también en el backend.
class DeleteEvidenceFile implements UseCase<void, DeleteEvidenceFileParams> {
  final EvidenceFolderRepository _repository;

  DeleteEvidenceFile(this._repository);

  @override
  Future<Either<Failure, void>> call(DeleteEvidenceFileParams params) async {
    return _repository.deleteFile(
      clubInstanceId: params.clubInstanceId,
      sectionId: params.sectionId,
      fileId: params.fileId,
    );
  }
}
