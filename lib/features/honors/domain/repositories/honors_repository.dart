import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/honor.dart';
import '../entities/honor_category.dart';
import '../entities/user_honor.dart';

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
}
