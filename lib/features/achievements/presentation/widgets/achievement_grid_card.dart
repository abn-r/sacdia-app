import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/achievement.dart';
import '../../domain/entities/user_achievement.dart';
import '../../domain/repositories/achievements_repository.dart';
import 'achievement_badge.dart';

/// Grid card for a single achievement — YouVersion badge style.
///
/// Dark card (#1C1C1E), centered column:
///   1. AchievementBadge (56px) — color if unlocked, grayscale if locked/in-progress
///   2. Counter pill — timesCompleted or progressValue
///   3. Achievement name (2 lines max)
///   4. Thin progress bar (3px)
///
/// Secret + locked: shows "?" icon, hides name, no progress bar.
class AchievementGridCard extends StatelessWidget {
  final AchievementWithProgress achievementWithProgress;
  final VoidCallback? onTap;

  const AchievementGridCard({
    super.key,
    required this.achievementWithProgress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final achievement = achievementWithProgress.achievement;
    final userAchievement = achievementWithProgress.userAchievement;

    final isCompleted = userAchievement?.isCompleted ?? false;
    final isSecret = achievement.secret && !isCompleted;
    final visualState =
        userAchievement?.visualState ?? AchievementVisualState.locked;

    final progressValue = userAchievement?.progressValue ?? 0;
    final progressTarget = userAchievement?.progressTarget ?? _extractTarget(achievement);
    final progressPercentage = userAchievement?.progressPercentage ?? 0.0;
    final timesCompleted = userAchievement?.timesCompleted ?? 0;

    final tierColor = achievementTierColor(achievement.tier);

    // Counter label: times completed for repeatable, progressValue otherwise
    final String counterLabel = isCompleted
        ? (achievement.repeatable && timesCompleted > 0
            ? timesCompleted.toString()
            : '1')
        : progressValue.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Badge
            if (isSecret)
              _SecretBadge()
            else
              AchievementBadge(
                badgeImageUrl: achievement.badgeImageUrl,
                tier: achievement.tier,
                visualState: visualState,
                isSecret: false,
                size: 56,
                progress: progressPercentage,
              ),

            const SizedBox(height: 4),

            // 2. Counter pill
            if (!isSecret)
              _CounterPill(
                label: counterLabel,
                isCompleted: isCompleted,
                tierColor: tierColor,
              ),

            if (!isSecret) const SizedBox(height: 4),

            // 3. Name — Flexible so it compresses instead of overflowing
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  isSecret ? '???' : achievement.name,
                  style: TextStyle(
                    color: context.sac.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            const SizedBox(height: 4),

            // 4. Progress bar — hidden for secret locked
            if (!isSecret)
              _ThinProgressBar(
                progress: progressPercentage,
                tierColor: tierColor,
              ),
          ],
        ),
      ),
    );
  }

  int _extractTarget(Achievement achievement) {
    final target = achievement.criteria['target'];
    if (target is int) return target;
    if (target is double) return target.toInt();
    if (target is String) return int.tryParse(target) ?? 0;
    return 0;
  }
}

// ── Secret badge placeholder ────────────────────────────────────────────────────

class _SecretBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        border: Border.all(color: context.sac.border, width: 1.5),
      ),
      child: Center(
        child: Text(
          '?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: context.sac.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ── Counter pill ────────────────────────────────────────────────────────────────

class _CounterPill extends StatelessWidget {
  final String label;
  final bool isCompleted;
  final Color tierColor;

  const _CounterPill({
    required this.label,
    required this.isCompleted,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isCompleted
        ? tierColor.withValues(alpha: 0.22)
        : context.sac.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isCompleted ? tierColor : context.sac.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Thin progress bar ───────────────────────────────────────────────────────────

class _ThinProgressBar extends StatelessWidget {
  final double progress; // 0.0 – 1.0
  final Color tierColor;

  const _ThinProgressBar({
    required this.progress,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final fillWidth = (totalWidth * progress.clamp(0.0, 1.0));

          return ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                // Track
                Container(
                  height: 3,
                  width: totalWidth,
                  color: context.sac.border,
                ),
                // Fill
                if (fillWidth > 0)
                  Container(
                    height: 3,
                    width: fillWidth,
                    decoration: BoxDecoration(
                      color: tierColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
