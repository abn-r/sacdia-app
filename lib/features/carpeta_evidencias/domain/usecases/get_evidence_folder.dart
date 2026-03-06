import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/evidence_folder.dart';
import '../repositories/evidence_folder_repository.dart';

class GetEvidenceFolderParams extends Equatable {
  final String clubInstanceId;

  const GetEvidenceFolderParams({required this.clubInstanceId});

  @override
  List<Object?> get props => [clubInstanceId];
}

/// Caso de uso: obtener la carpeta de evidencias de una instancia de club.
class GetEvidenceFolder
    implements UseCase<EvidenceFolder, GetEvidenceFolderParams> {
  final EvidenceFolderRepository _repository;

  GetEvidenceFolder(this._repository);

  @override
  Future<Either<Failure, EvidenceFolder>> call(
      GetEvidenceFolderParams params) async {
    return _repository.getEvidenceFolder(params.clubInstanceId);
  }
}
