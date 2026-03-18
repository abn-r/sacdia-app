import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/evidence_folder_repository.dart';

class SubmitSectionParams extends Equatable {
  final String clubSectionId;
  final String sectionId;

  const SubmitSectionParams({
    required this.clubSectionId,
    required this.sectionId,
  });

  @override
  List<Object?> get props => [clubSectionId, sectionId];
}

/// Caso de uso: enviar una sección a validación (pendiente → enviado).
class SubmitSection implements UseCase<void, SubmitSectionParams> {
  final EvidenceFolderRepository _repository;

  SubmitSection(this._repository);

  @override
  Future<Either<Failure, void>> call(SubmitSectionParams params) async {
    return _repository.submitSection(
      params.clubSectionId,
      params.sectionId,
    );
  }
}
