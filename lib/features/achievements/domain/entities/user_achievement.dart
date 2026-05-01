import 'package:equatable/equatable.dart';

/// Visual state of an achievement badge
enum AchievementVisualState {
  locked,
  inProgress,
  unlocked,
}

/// Entidad de logro del usuario del dominio.
///
/// Combina datos del backend con computed helpers para la UI.
class UserAchievement extends Equatable {
  final int userAchievementId;
  final int achievementId;
  final int progressValue;
  final int progressTarget;
  final Map<String, dynamic>? progressMetadata;
  final bool completed;
  final DateTime? completedAt;
  final int timesCompleted;

  const UserAchievement({
    required this.userAchievementId,
    required this.achievementId,
    this.progressValue = 0,
    this.progressTarget = 1,
    this.progressMetadata,
    this.completed = false,
    this.completedAt,
    this.timesCompleted = 0,
  });

  // ── Computed helpers ────────────────────────────────────────────────────────

  /// Progreso de 0.0 a 1.0 para barras de progreso y rings.
  double get progressPercentage {
    if (progressTarget <= 0) return completed ? 1.0 : 0.0;
    return (progressValue / progressTarget).clamp(0.0, 1.0);
  }

  /// True si el logro está completado.
  bool get isCompleted => completed;

  /// True si hay progreso pero no está completado todavía.
  bool get isInProgress => progressValue > 0 && !completed;

  /// Estado visual para el badge widget.
  AchievementVisualState get visualState {
    if (completed) return AchievementVisualState.unlocked;
    if (isInProgress) return AchievementVisualState.inProgress;
    return AchievementVisualState.locked;
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
