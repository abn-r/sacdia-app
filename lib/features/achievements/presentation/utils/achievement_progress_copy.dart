import '../../domain/entities/user_achievement.dart';

/// Remaining units toward target; never negative. Invalid target → 0.
int remainingFor(UserAchievement ua) {
  final target = ua.progressTarget;
  if (target <= 0) return 0;
  final rem = target - ua.progressValue;
  return rem < 0 ? 0 : rem;
}

/// Progress ratio clamped to \[0, 1\], safe for bad targets.
double clampedProgressRatio(UserAchievement ua) {
  return ua.progressPercentage.clamp(0.0, 1.0);
}

/// Whether remaining subtitle / NEXT block should show a remaining count.
bool shouldShowRemainingCount(UserAchievement ua) {
  return ua.progressTarget > 0 && remainingFor(ua) > 0;
}
