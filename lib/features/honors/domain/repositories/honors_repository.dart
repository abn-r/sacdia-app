import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/honor.dart';
import '../entities/honor_category.dart';
import '../entities/honor_group.dart';
import '../entities/honor_requirement.dart';
import '../entities/user_honor.dart';
import '../usecases/register_user_honor.dart';

/// Repositorio de especialidades (interfaz del dominio)
abstract class HonorsRepository {
  /// Obtiene todas las categorías de especialidades
  Future<Either<Failure, List<HonorCategory>>> getHonorCategories();

  /// Obtiene especialidades filtradas
  Future<Either<Failure, List<Honor>>> getHonors({
    int? categoryId,
    int? clubTypeId,
    int? skillLevel,
  });

  /// Obtiene el detalle de una especialidad
  Future<Either<Failure, Honor>> getHonorById(int honorId);

  /// Obtiene las especialidades de un usuario
  Future<Either<Failure, List<UserHonor>>> getUserHonors(String userId);

  /// Obtiene estadísticas de especialidades de un usuario
  Future<Either<Failure, Map<String, dynamic>>> getUserHonorStats(String userId);

  /// Inscribe a un usuario en una especialidad
  Future<Either<Failure, UserHonor>> enrollUserInHonor(String userId, int honorId);

  /// Actualiza el estado de una especialidad de usuario
  Future<Either<Failure, UserHonor>> updateUserHonor(
    String userId,
    int honorId,
    Map<String, dynamic> data,
  );

  /// Elimina la inscripción de un usuario en una especialidad
  Future<Either<Failure, void>> deleteUserHonor(String userId, int honorId);

  /// Registra una especialidad completada con datos de evidencia
  Future<Either<Failure, UserHonor>> registerUserHonor(
    RegisterUserHonorParams params,
  );

  /// Obtiene las especialidades agrupadas por categoría
  Future<Either<Failure, List<HonorGroup>>> getHonorsGroupedByCategory();

  /// Obtiene los requisitos del catálogo para una especialidad
  Future<Either<Failure, List<HonorRequirement>>> getHonorRequirements(
      int honorId);

  /// Obtiene el progreso del usuario por requisito para una especialidad inscripta.
  /// Devuelve un mapa con claves: totalRequirements, completedCount,
  /// progressPercentage y requirements (lista de progreso por requisito).
  Future<Either<Failure, Map<String, dynamic>>> getUserHonorProgress(
      String userId, int userHonorId);

  /// Actualiza el progreso de múltiples requisitos en una sola operación.
  /// [updates] es una lista de mapas con requirementId, completed y notes opcional.
  Future<Either<Failure, Map<String, dynamic>>> bulkUpdateRequirementProgress(
      String userId,
      int userHonorId,
      List<Map<String, dynamic>> updates);
}
