import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_honor_requirement_progress.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para obtener el progreso del usuario por requisito en una especialidad.
///
/// El userId se deriva del JWT en el backend — no se pasa explícitamente.
/// Devuelve la lista de [UserHonorRequirementProgress] para todos los requisitos.
class GetUserHonorProgress
    implements UseCase<List<UserHonorRequirementProgress>, GetUserHonorProgressParams> {
  final HonorsRepository repository;

  GetUserHonorProgress(this.repository);

  @override
  Future<Either<Failure, List<UserHonorRequirementProgress>>> call(
      GetUserHonorProgressParams params) async {
    return await repository.getUserHonorProgress(params.honorId);
  }
}

/// Parámetros para obtener el progreso de requisitos de usuario
class GetUserHonorProgressParams {
  final int honorId;

  const GetUserHonorProgressParams({
    required this.honorId,
  });
}
