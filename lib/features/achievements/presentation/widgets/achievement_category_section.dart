import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/repositories/achievements_repository.dart';
import 'achievement_card.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

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
            onTap:
                onAchievementTap != null ? () => onAchievementTap!(item) : null,
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
        ? SacAccent.of(context).color.withValues(alpha: 0.15)
        : SacAccent.of(context).light;
    final titleColor =
        isDark ? SacAccent.of(context).color : SacAccent.of(context).dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
      child: Row(
        children: [
          // Icon
          HugeIcon(
            icon: HugeIcons.strokeRoundedAward01,
            size: 18,
            color: SacAccent.of(context).color,
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
                  ? context.sac.successContainer
                  : context.sac.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
            child: Text(
              '$completedCount/$totalCount',
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w600,
                color: completedCount == totalCount
                    ? context.sac.onSuccessContainer
                    : context.sac.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
