import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/classes_repository.dart';

class SubmitRequirementParams extends Equatable {
  final String userId;
  final int classId;
  final int requirementId;
  final int? enrollmentId;

  const SubmitRequirementParams({
    required this.userId,
    required this.classId,
    required this.requirementId,
    this.enrollmentId,
  });

  @override
  List<Object?> get props => [userId, classId, requirementId, enrollmentId];
}

/// Caso de uso: envia un requerimiento a validacion (pendiente -> enviado).
class SubmitRequirement implements UseCase<void, SubmitRequirementParams> {
  final ClassesRepository _repository;

  SubmitRequirement(this._repository);

  @override
  Future<Either<Failure, void>> call(SubmitRequirementParams params) async {
    return _repository.submitRequirement(
      params.userId,
      params.classId,
      params.requirementId,
      enrollmentId: params.enrollmentId,
    );
  }
}
