import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para eliminar una evidencia de un requisito de especialidad.
///
/// Elimina de forma permanente el archivo o enlace indicado.
/// No retorna dato en el Right — solo confirma que la operación fue exitosa.
class DeleteRequirementEvidence
    implements UseCase<void, DeleteRequirementEvidenceParams> {
  final HonorsRepository repository;

  DeleteRequirementEvidence(this.repository);

  @override
  Future<Either<Failure, void>> call(
      DeleteRequirementEvidenceParams params) async {
    return await repository.deleteRequirementEvidence(
      params.userId,
      params.honorId,
      params.requirementId,
      params.evidenceId,
    );
  }
}

/// Parámetros para eliminar una evidencia de requisito
class DeleteRequirementEvidenceParams {
  final String userId;
  final int honorId;
  final int requirementId;
  final int evidenceId;

  const DeleteRequirementEvidenceParams({
    required this.userId,
    required this.honorId,
    required this.requirementId,
    required this.evidenceId,
  });
}
