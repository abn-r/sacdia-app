import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/evidence_folder.dart';
import '../repositories/evidence_folder_repository.dart';

class GetEvidenceFolderParams extends Equatable {
  final String clubSectionId;

  const GetEvidenceFolderParams({required this.clubSectionId});

  @override
  List<Object?> get props => [clubSectionId];
}

/// Caso de uso: obtener la carpeta de evidencias de una sección de club.
class GetEvidenceFolder
    implements UseCase<EvidenceFolder, GetEvidenceFolderParams> {
  final EvidenceFolderRepository _repository;

  GetEvidenceFolder(this._repository);

  @override
  Future<Either<Failure, EvidenceFolder>> call(
      GetEvidenceFolderParams params) async {
    return _repository.getEvidenceFolder(params.clubSectionId);
  }
}
