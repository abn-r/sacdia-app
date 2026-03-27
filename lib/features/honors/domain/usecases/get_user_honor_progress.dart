import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para obtener el progreso del usuario por requisito en una especialidad.
///
/// Devuelve un mapa con las claves:
/// - totalRequirements: número total de requisitos
/// - completedCount: cantidad de requisitos completados
/// - progressPercentage: porcentaje de completado (0-100, 2 decimales)
/// - requirements: lista de progreso por requisito
class GetUserHonorProgress
    implements UseCase<Map<String, dynamic>, GetUserHonorProgressParams> {
  final HonorsRepository repository;

  GetUserHonorProgress(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
      GetUserHonorProgressParams params) async {
    return await repository.getUserHonorProgress(
        params.userId, params.honorId);
  }
}

/// Parámetros para obtener el progreso de requisitos de usuario
class GetUserHonorProgressParams {
  final String userId;
  final int honorId;

  const GetUserHonorProgressParams({
    required this.userId,
    required this.honorId,
  });
}
