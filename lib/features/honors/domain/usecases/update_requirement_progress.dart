import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_honor_requirement_progress.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para actualizar el progreso de múltiples requisitos en batch.
///
/// Devuelve la lista actualizada de [UserHonorRequirementProgress].
class UpdateRequirementProgress
    implements
        UseCase<List<UserHonorRequirementProgress>, UpdateRequirementProgressParams> {
  final HonorsRepository repository;

  UpdateRequirementProgress(this.repository);

  @override
  Future<Either<Failure, List<UserHonorRequirementProgress>>> call(
      UpdateRequirementProgressParams params) async {
    return await repository.bulkUpdateRequirementProgress(
        params.honorId, params.updates);
  }
}

/// Parámetros para actualizar el progreso de requisitos en batch
class UpdateRequirementProgressParams {
  final int honorId;

  /// Lista de actualizaciones. Cada mapa debe tener:
  /// - requirementId: int
  /// - completed: bool
  /// - notes: String? (opcional)
  final List<Map<String, dynamic>> updates;

  const UpdateRequirementProgressParams({
    required this.honorId,
    required this.updates,
  });
}
