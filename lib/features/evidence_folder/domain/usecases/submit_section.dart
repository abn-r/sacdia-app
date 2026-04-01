import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/evidence_folder_repository.dart';

class SubmitFolderParams extends Equatable {
  final String folderId;

  const SubmitFolderParams({required this.folderId});

  @override
  List<Object?> get props => [folderId];
}

/// Caso de uso: enviar la carpeta completa a validación.
///
/// AnnualFolders opera sobre la carpeta entera, no por sección individual.
class SubmitFolder implements UseCase<void, SubmitFolderParams> {
  final EvidenceFolderRepository _repository;

  SubmitFolder(this._repository);

  @override
  Future<Either<Failure, void>> call(SubmitFolderParams params) async {
    return _repository.submitFolder(params.folderId);
  }
}
