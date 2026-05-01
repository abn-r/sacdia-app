import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/repositories/achievements_repository.dart';
import 'achievement_card.dart';

/// Sección de una categoría de logros con header y lista de cards.
///
/// El header muestra el ícono de la categoría (si existe), el nombre,
/// y el conteo "X completados / Y total".
class AchievementCategorySection extends StatelessWidget {
  final UserAchievementCategoryGroup group;

  /// Callback cuando se toca un logro. Recibe el [AchievementWithProgress].
  final void Function(AchievementWithProgress item)? onAchievementTap;

  /// Si true, la sección inicia expandida. Default: true.
  final bool initiallyExpanded;

  const AchievementCategorySection({
    super.key,
    required this.group,
    this.onAchievementTap,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final completed = group.achievements
        .where((a) => a.userAchievement?.isCompleted ?? false)
        .length;
    final total = group.achievements.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        _CategoryHeader(
          categoryName: group.category.name,
          icon: group.category.icon,
          completedCount: completed,
          totalCount: total,
        ),
        const SizedBox(height: 8),

        // Achievement cards
        ...group.achievements.map((item) {
          return AchievementCard(
            achievementWithProgress: item,
            onTap: onAchievementTap != null
                ? () => onAchievementTap!(item)
                : null,
          );
        }),

        const SizedBox(height: 8),
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String categoryName;
  final String? icon;
  final int completedCount;
  final int totalCount;

  const _CategoryHeader({
    required this.categoryName,
    this.icon,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark
        ? AppColors.primary.withValues(alpha: 0.15)
        : AppColors.primaryLight;
    final titleColor = isDark ? AppColors.primary : AppColors.primaryDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Icon
          HugeIcon(
            icon: HugeIcons.strokeRoundedAward01,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),

          // Category name
          Expanded(
            child: Text(
              categoryName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Progress badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: completedCount == totalCount
                  ? (isDark
                      ? AppColors.secondary.withValues(alpha: 0.2)
                      : AppColors.secondaryLight)
                  : context.sac.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$completedCount/$totalCount',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: completedCount == totalCount
                    ? (isDark ? AppColors.secondary : AppColors.secondaryDark)
                    : context.sac.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
