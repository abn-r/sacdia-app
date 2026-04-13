import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/evidence_folder_repository.dart';

// ── SubmitFolder ──────────────────────────────────────────────────────────────

class SubmitFolderParams extends Equatable {
  final String folderId;

  const SubmitFolderParams({required this.folderId});

  @override
  List<Object?> get props => [folderId];
}

/// Caso de uso: enviar la carpeta completa a validación.
///
/// Disponible para coordinadores que necesitan enviar toda la carpeta de una vez.
class SubmitFolder implements UseCase<void, SubmitFolderParams> {
  final EvidenceFolderRepository _repository;

  SubmitFolder(this._repository);

  @override
  Future<Either<Failure, void>> call(SubmitFolderParams params) async {
    return _repository.submitFolder(params.folderId);
  }
}

// ── SubmitSection ─────────────────────────────────────────────────────────────

class SubmitSectionParams extends Equatable {
  final String folderId;
  final String sectionId;

  const SubmitSectionParams({
    required this.folderId,
    required this.sectionId,
  });

  @override
  List<Object?> get props => [folderId, sectionId];
}

/// Caso de uso: enviar una sección individual a validación.
///
/// Permite que el director envíe sección por sección en lugar de la carpeta
/// completa, utilizando el endpoint
/// POST /annual-folders/:folderId/sections/:sectionId/submit.
class SubmitSection implements UseCase<void, SubmitSectionParams> {
  final EvidenceFolderRepository _repository;

  SubmitSection(this._repository);

  @override
  Future<Either<Failure, void>> call(SubmitSectionParams params) async {
    return _repository.submitSection(
      folderId: params.folderId,
      sectionId: params.sectionId,
    );
  }
}
