import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

import '../../domain/entities/achievement.dart';
import '../../domain/entities/user_achievement.dart';
import '../../domain/repositories/achievements_repository.dart';
import '../widgets/achievement_badge.dart';
import '../widgets/achievement_progress_bar.dart';

/// Bottom sheet de detalle de un logro.
///
/// Contenido:
/// - AchievementBadge grande (96px) centrado
/// - Nombre, descripción, badges de tier y puntos
/// - Barra de progreso (si no está completado)
/// - Para COLLECTION: checklist de items coleccionados/faltantes
/// - Para STREAK: contador de racha
/// - Cadena de prerequisito (si aplica)
/// - Contador de veces completado (si repeatable)
/// - Fecha de completado (si completado)
class AchievementDetailSheet extends StatelessWidget {
  final AchievementWithProgress achievementWithProgress;

  const AchievementDetailSheet({
    super.key,
    required this.achievementWithProgress,
  });

  @override
  Widget build(BuildContext context) {
    final achievement = achievementWithProgress.achievement;
    final userAchievement = achievementWithProgress.userAchievement;

    final isCompleted = userAchievement?.isCompleted ?? false;
    final isSecret = achievement.secret && !isCompleted;
    final visualState = userAchievement?.visualState ?? AchievementVisualState.locked;
    final tierColor = achievementTierColor(achievement.tier);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.sac.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.sac.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Badge large
                      AchievementBadge(
                        badgeImageUrl: achievement.badgeImageUrl,
                        tier: achievement.tier,
                        visualState: visualState,
                        isSecret: achievement.secret,
                        size: 96,
                        progress: userAchievement?.progressPercentage ?? 0.0,
                      ),
                      const SizedBox(height: 16),

                      // Name
                      Text(
                        isSecret ? '???' : achievement.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Tier + Points badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Tier badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    size: 8, color: tierColor),
                                const SizedBox(width: 4),
                                Text(
                                  achievement.tier.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: tierColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Points badge
                          SacBadge.warning(
                            label: '${achievement.points} pts',
                            icon: Icons.bolt,
                          ),
                          if (achievement.repeatable) ...[
                            const SizedBox(width: 8),
                            SacBadge(
                              label: 'achievements.views.detail_repeatable'.tr(),
                              variant: SacBadgeVariant.secondary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description
                      if (!isSecret && achievement.description != null) ...[
                        Text(
                          achievement.description!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: context.sac.textSecondary,
                                  height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Progress bar (if not completed)
                      if (userAchievement != null && !isCompleted) ...[
                        _ProgressSection(
                          userAchievement: userAchievement,
                          achievement: achievement,
                        ),
                        const SizedBox(height: 20),
                      ],

                      const Divider(),
                      const SizedBox(height: 12),

                      // Type-specific content
                      if (!isSecret) ...[
                        _TypeSpecificContent(
                          achievement: achievement,
                          userAchievement: userAchievement,
                        ),
                      ],

                      // Prerequisite
                      if (achievement.prerequisiteId != null) ...[
                        _PrerequisiteChip(
                            prerequisiteId: achievement.prerequisiteId!),
                        const SizedBox(height: 12),
                      ],

                      // Times completed (repeatable)
                      if (achievement.repeatable &&
                          userAchievement != null &&
                          userAchievement.timesCompleted > 0) ...[
                        _InfoRow(
                          icon: HugeIcons.strokeRoundedRefresh,
                          label: 'achievements.views.detail_times_completed'.tr(),
                          value: userAchievement.timesCompleted.toString(),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Completed date
                      if (isCompleted &&
                          userAchievement?.completedAt != null) ...[
                        _InfoRow(
                          icon: HugeIcons.strokeRoundedCalendar01,
                          label: 'achievements.views.detail_completed_on'.tr(),
                          value: _formatDate(userAchievement!.completedAt!),
                        ),
                        const SizedBox(height: 8),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ── Progress Section ────────────��──────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final UserAchievement userAchievement;
  final Achievement achievement;

  const _ProgressSection({
    required this.userAchievement,
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'achievements.views.detail_progress'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              '${userAchievement.progressValue}/${userAchievement.progressTarget}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: achievementTierColor(achievement.tier),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AchievementProgressBar(
          progress: userAchievement.progressPercentage,
          tier: achievement.tier,
          height: 8,
        ),
      ],
    );
  }
}

// ── Type-Specific Content ─────────────────────────────────────────────────────��

class _TypeSpecificContent extends StatelessWidget {
  final Achievement achievement;
  final UserAchievement? userAchievement;

  const _TypeSpecificContent({
    required this.achievement,
    this.userAchievement,
  });

  @override
  Widget build(BuildContext context) {
    switch (achievement.type) {
      case AchievementType.collection:
        return _CollectionContent(
          achievement: achievement,
          userAchievement: userAchievement,
        );
      case AchievementType.streak:
        return _StreakContent(
          achievement: achievement,
          userAchievement: userAchievement,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _CollectionContent extends StatelessWidget {
  final Achievement achievement;
  final UserAchievement? userAchievement;

  const _CollectionContent({
    required this.achievement,
    this.userAchievement,
  });

  @override
  Widget build(BuildContext context) {
    // Extract items from criteria and collected from progress_metadata
    final requiredItems =
        (achievement.criteria['items'] as List<dynamic>?)?.cast<String>() ?? [];
    final collectedItems = (userAchievement?.progressMetadata?['collected']
                as List<dynamic>?)
            ?.cast<String>() ??
        [];

    if (requiredItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'achievements.views.detail_collection'.tr(),
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...requiredItems.map((item) {
          final isCollected = collectedItems.contains(item);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  isCollected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: isCollected
                      ? AppColors.secondary
                      : context.sac.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 13,
                      color: isCollected
                          ? context.sac.text
                          : context.sac.textSecondary,
                      decoration:
                          isCollected ? TextDecoration.none : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _StreakContent extends StatelessWidget {
  final Achievement achievement;
  final UserAchievement? userAchievement;

  const _StreakContent({
    required this.achievement,
    this.userAchievement,
  });

  @override
  Widget build(BuildContext context) {
    final currentStreak = userAchievement?.progressValue ?? 0;
    final requiredStreak =
        userAchievement?.progressTarget ?? (achievement.criteria['streak'] as int? ?? 0);
    final tierColor = achievementTierColor(achievement.tier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'achievements.views.detail_streak'.tr(),
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAward01,
              size: 32,
              color: tierColor,
            ),
            const SizedBox(width: 8),
            Text(
              '$currentStreak',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: tierColor,
              ),
            ),
            if (requiredStreak > 0) ...[
              Text(
                ' / $requiredStreak días',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.sac.textSecondary,
                    ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _PrerequisiteChip extends StatelessWidget {
  final int prerequisiteId;
  const _PrerequisiteChip({required this.prerequisiteId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedLink01,
            size: 16,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 8),
          Text(
            'achievements.views.detail_prerequisite'.tr(namedArgs: {'id': '$prerequisiteId'}),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 16, color: context.sac.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: context.sac.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.sac.text,
          ),
        ),
      ],
    );
  }
}
