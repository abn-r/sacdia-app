import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para actualizar el progreso de múltiples requisitos en batch.
///
/// Devuelve el progreso actualizado igual que [GetUserHonorProgress].
class UpdateRequirementProgress
    implements
        UseCase<Map<String, dynamic>, UpdateRequirementProgressParams> {
  final HonorsRepository repository;

  UpdateRequirementProgress(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
      UpdateRequirementProgressParams params) async {
    return await repository.bulkUpdateRequirementProgress(
        params.userId, params.honorId, params.updates);
  }
}

/// Parámetros para actualizar el progreso de requisitos en batch
class UpdateRequirementProgressParams {
  final String userId;
  final int honorId;

  /// Lista de actualizaciones. Cada mapa debe tener:
  /// - requirementId: int
  /// - completed: bool
  /// - notes: String? (opcional)
  final List<Map<String, dynamic>> updates;

  const UpdateRequirementProgressParams({
    required this.userId,
    required this.honorId,
    required this.updates,
  });
}
