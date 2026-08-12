import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/achievements/domain/entities/user_achievement.dart';
import 'package:sacdia_app/features/achievements/presentation/utils/achievement_progress_copy.dart';

void main() {
  group('remainingFor', () {
    test('returns target - current when positive', () {
      const ua = UserAchievement(
        userAchievementId: 1,
        achievementId: 1,
        progressValue: 2,
        progressTarget: 5,
      );
      expect(remainingFor(ua), 3);
    });

    test('clamps at 0 when current exceeds target', () {
      const ua = UserAchievement(
        userAchievementId: 1,
        achievementId: 1,
        progressValue: 8,
        progressTarget: 5,
      );
      expect(remainingFor(ua), 0);
    });

    test('returns 0 when target <= 0', () {
      const ua = UserAchievement(
        userAchievementId: 1,
        achievementId: 1,
        progressValue: 2,
        progressTarget: 0,
      );
      expect(remainingFor(ua), 0);
    });
  });

  group('clampedProgressRatio', () {
    test('returns 0–1 for normal progress', () {
      const ua = UserAchievement(
        userAchievementId: 1,
        achievementId: 1,
        progressValue: 2,
        progressTarget: 5,
      );
      expect(clampedProgressRatio(ua), closeTo(0.4, 0.001));
    });

    test('stays in 0–1 when target is invalid', () {
      const ua = UserAchievement(
        userAchievementId: 1,
        achievementId: 1,
        progressValue: 2,
        progressTarget: 0,
      );
      expect(clampedProgressRatio(ua), inInclusiveRange(0, 1));
    });
  });

  group('shouldShowRemainingCount', () {
    test('true when remaining > 0', () {
      const ua = UserAchievement(
        userAchievementId: 1,
        achievementId: 1,
        progressValue: 2,
        progressTarget: 5,
      );
      expect(shouldShowRemainingCount(ua), isTrue);
    });

    test('false when target <= 0', () {
      const ua = UserAchievement(
        userAchievementId: 1,
        achievementId: 1,
        progressValue: 2,
        progressTarget: 0,
      );
      expect(shouldShowRemainingCount(ua), isFalse);
    });
  });
}
