import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_honor.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para inscribir a un usuario en una especialidad
class StartHonor implements UseCase<UserHonor, StartHonorParams> {
  final HonorsRepository repository;

  StartHonor(this.repository);

  @override
  Future<Either<Failure, UserHonor>> call(StartHonorParams params) async {
    return await repository.enrollUserInHonor(params.userId, params.honorId);
  }
}

/// Parámetros para inscribir en una especialidad
class StartHonorParams {
  final String userId;
  final int honorId;

  const StartHonorParams({
    required this.userId,
    required this.honorId,
  });
}
