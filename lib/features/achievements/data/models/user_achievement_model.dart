import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/user_achievement.dart';

/// Modelo de logro del usuario para la capa de datos
class UserAchievementModel extends Equatable {
  final int userAchievementId;
  final int achievementId;
  final int progressValue;
  final int progressTarget;
  final Map<String, dynamic>? progressMetadata;
  final bool completed;
  final DateTime? completedAt;
  final int timesCompleted;

  const UserAchievementModel({
    required this.userAchievementId,
    required this.achievementId,
    this.progressValue = 0,
    this.progressTarget = 1,
    this.progressMetadata,
    this.completed = false,
    this.completedAt,
    this.timesCompleted = 0,
  });

  factory UserAchievementModel.fromJson(Map<String, dynamic> json) {
    DateTime? completedAt;
    final rawCompletedAt = safeStringOrNull(json['completed_at']);
    if (rawCompletedAt != null) {
      completedAt = DateTime.tryParse(rawCompletedAt);
    }

    // Parse progress_metadata — can be Map or null
    Map<String, dynamic>? progressMetadata;
    final rawMeta = json['progress_metadata'];
    if (rawMeta is Map<String, dynamic>) {
      progressMetadata = rawMeta;
    }

    return UserAchievementModel(
      userAchievementId: safeInt(
        json['user_achievement_id'] ?? json['id'],
      ),
      achievementId: safeInt(json['achievement_id']),
      progressValue: safeInt(json['progress_value']),
      progressTarget: safeInt(json['progress_target'], 1),
      progressMetadata: progressMetadata,
      completed: safeBool(json['completed']),
      completedAt: completedAt,
      timesCompleted: safeInt(json['times_completed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_achievement_id': userAchievementId,
      'achievement_id': achievementId,
      'progress_value': progressValue,
      'progress_target': progressTarget,
      'progress_metadata': progressMetadata,
      'completed': completed,
      'completed_at': completedAt?.toIso8601String(),
      'times_completed': timesCompleted,
    };
  }

  UserAchievement toEntity() {
    return UserAchievement(
      userAchievementId: userAchievementId,
      achievementId: achievementId,
      progressValue: progressValue,
      progressTarget: progressTarget,
      progressMetadata: progressMetadata,
      completed: completed,
      completedAt: completedAt,
      timesCompleted: timesCompleted,
    );
  }

  @override
  List<Object?> get props => [
        userAchievementId,
        achievementId,
        progressValue,
        progressTarget,
        progressMetadata,
        completed,
        completedAt,
        timesCompleted,
      ];
}
