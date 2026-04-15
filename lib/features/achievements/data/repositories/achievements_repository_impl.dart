import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/achievement_category.dart';
import '../../domain/repositories/achievements_repository.dart';
import '../datasources/achievements_remote_data_source.dart';

/// Implementación del repositorio de logros
class AchievementsRepositoryImpl implements AchievementsRepository {
  final AchievementsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  AchievementsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<UserAchievementCategoryGroup>>>
      getAchievements() async {
    try {
      final rawGroups = await remoteDataSource.getAchievements();
      final groups = rawGroups.map((raw) {
        return UserAchievementCategoryGroup(
          category: raw.category.toEntity(),
          achievements: raw.achievements.map((a) {
            return AchievementWithProgress(
              achievement: a.achievement.toEntity(),
              userAchievement: a.userAchievement?.toEntity(),
            );
          }).toList(),
        );
      }).toList();
      return Right(groups);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserAchievementsResponse>>
      getUserAchievements() async {
    try {
      final raw = await remoteDataSource.getUserAchievements();

      final summary = UserAchievementsSummary(
        totalCompleted: (raw.summary['total_completed'] as num?)?.toInt() ?? 0,
        totalPoints: (raw.summary['total_points'] as num?)?.toInt() ?? 0,
        completionPercentage:
            (raw.summary['completion_percentage'] as num?)?.toDouble() ?? 0.0,
      );

      final categories = raw.categories.map((rawGroup) {
        return UserAchievementCategoryGroup(
          category: rawGroup.category.toEntity(),
          achievements: rawGroup.achievements.map((a) {
            return AchievementWithProgress(
              achievement: a.achievement.toEntity(),
              userAchievement: a.userAchievement?.toEntity(),
            );
          }).toList(),
        );
      }).toList();

      return Right(UserAchievementsResponse(
        summary: summary,
        categories: categories,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AchievementCategory>>> getCategories() async {
    try {
      final models = await remoteDataSource.getCategories();
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
