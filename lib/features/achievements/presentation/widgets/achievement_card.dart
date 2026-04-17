import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/achievement.dart';
import '../../domain/entities/user_achievement.dart';
import '../../domain/repositories/achievements_repository.dart';
import 'achievement_badge.dart';
import 'achievement_progress_bar.dart';

/// Card de un logro individual.
///
/// Muestra: AchievementBadge (64x64) a la izquierda, nombre + descripción
/// a la derecha, y barra de progreso con tier color en la parte inferior.
/// Tap → callback [onTap] (navega al detalle / abre el sheet).
/// Logros secretos no completados muestran "???" en título y descripción.
class AchievementCard extends StatelessWidget {
  final AchievementWithProgress achievementWithProgress;
  final VoidCallback? onTap;

  const AchievementCard({
    super.key,
    required this.achievementWithProgress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final achievement = achievementWithProgress.achievement;
    final userAchievement = achievementWithProgress.userAchievement;

    final visualState = userAchievement?.visualState ?? AchievementVisualState.locked;
    final isCompleted = userAchievement?.isCompleted ?? false;
    final isSecret = achievement.secret && !isCompleted;

    final progressValue = userAchievement?.progressValue ?? 0;
    final progressTarget =
        userAchievement?.progressTarget ?? _extractTarget(achievement);
    final progressPercentage = userAchievement?.progressPercentage ?? 0.0;

    final String displayTitle = isSecret ? '???' : achievement.name;
    final String? displayDescription =
        isSecret ? null : achievement.description;

    final tierColor = achievementTierColor(achievement.tier);

    return SacCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: isCompleted ? tierColor.withValues(alpha: 0.5) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Badge
          AchievementBadge(
            badgeImageUrl: achievement.badgeImageUrl,
            tier: achievement.tier,
            visualState: visualState,
            isSecret: achievement.secret,
            size: 64,
            progress: progressPercentage,
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title row with tier indicator
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isSecret
                                  ? context.sac.textTertiary
                                  : context.sac.text,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Tier dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: tierColor,
                        shape: BoxShape.circle,
                        boxShadow: isCompleted
                            ? [
                                BoxShadow(
                                  color: tierColor.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                )
                              ]
                            : [],
                      ),
                    ),
                  ],
                ),

                // Description
                if (displayDescription != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    displayDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.sac.textSecondary,
                          fontSize: 11,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 8),

                // Progress bar
                if (!isCompleted)
                  AchievementProgressBar(
                    progress: progressPercentage,
                    tier: achievement.tier,
                    height: 5,
                    label: progressTarget > 0
                        ? '$progressValue/$progressTarget'
                        : null,
                  )
                else
                  // Completed: show points
                  Row(
                    children: [
                      Icon(Icons.bolt, size: 12, color: tierColor),
                      const SizedBox(width: 2),
                      Text(
                        '${achievement.points} pts',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tierColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Chevron
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.chevron_right,
              size: 18,
              color: context.sac.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// Extrae el target de progreso desde los criterios del logro.
  int _extractTarget(Achievement achievement) {
    final target = achievement.criteria['target'];
    if (target is int) return target;
    if (target is double) return target.toInt();
    if (target is String) return int.tryParse(target) ?? 0;
    return 0;
  }
}
