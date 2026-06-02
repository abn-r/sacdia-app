import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/classes_repository.dart';

class DeleteRequirementFileParams extends Equatable {
  final String userId;
  final int classId;
  final int requirementId;
  final String fileId;
  final int? enrollmentId;

  const DeleteRequirementFileParams({
    required this.userId,
    required this.classId,
    required this.requirementId,
    required this.fileId,
    this.enrollmentId,
  });

  @override
  List<Object?> get props =>
      [userId, classId, requirementId, fileId, enrollmentId];
}

/// Caso de uso: elimina un archivo de evidencia de un requerimiento.
class DeleteRequirementFile
    implements UseCase<void, DeleteRequirementFileParams> {
  final ClassesRepository _repository;

  DeleteRequirementFile(this._repository);

  @override
  Future<Either<Failure, void>> call(DeleteRequirementFileParams params) async {
    return _repository.deleteRequirementFile(
      userId: params.userId,
      classId: params.classId,
      requirementId: params.requirementId,
      fileId: params.fileId,
      enrollmentId: params.enrollmentId,
    );
  }
}
