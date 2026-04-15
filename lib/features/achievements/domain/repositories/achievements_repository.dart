import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/achievement.dart';
import '../entities/achievement_category.dart';
import '../entities/user_achievement.dart';

/// Respuesta de GET /achievements/me con summary y categorías
class UserAchievementsResponse {
  final UserAchievementsSummary summary;
  final List<UserAchievementCategoryGroup> categories;

  const UserAchievementsResponse({
    required this.summary,
    required this.categories,
  });
}

/// Resumen de logros del usuario
class UserAchievementsSummary {
  final int totalCompleted;
  final int totalPoints;
  final double completionPercentage;

  const UserAchievementsSummary({
    required this.totalCompleted,
    required this.totalPoints,
    required this.completionPercentage,
  });
}

/// Categoría con sus logros y progreso del usuario
class UserAchievementCategoryGroup {
  final AchievementCategory category;
  final List<AchievementWithProgress> achievements;

  const UserAchievementCategoryGroup({
    required this.category,
    required this.achievements,
  });
}

/// Logro combinado con el progreso del usuario (puede ser null si no hay progreso)
class AchievementWithProgress {
  final Achievement achievement;
  final UserAchievement? userAchievement;

  const AchievementWithProgress({
    required this.achievement,
    this.userAchievement,
  });
}

/// Repositorio de logros (interfaz del dominio)
abstract class AchievementsRepository {
  /// Obtiene el catálogo de logros agrupado por categoría
  Future<Either<Failure, List<UserAchievementCategoryGroup>>> getAchievements();

  /// Obtiene los logros del usuario con summary de progreso
  Future<Either<Failure, UserAchievementsResponse>> getUserAchievements();

  /// Obtiene la lista de categorías de logros
  Future<Either<Failure, List<AchievementCategory>>> getCategories();
}
