import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/sac_rolling_number.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/achievement.dart';
import '../../domain/entities/user_achievement.dart';

/// Rounded chip with an optional leading mark (an icon or a coloured dot) and
/// a label.
class AchievementDetailChip extends StatelessWidget {
  const AchievementDetailChip({
    super.key,
    this.leading,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final Widget? leading;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              fontWeight: FontWeight.w700,
              color: foreground,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small coloured dot, the leading mark of the tier chip.
class AchievementTierDot extends StatelessWidget {
  const AchievementTierDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: 8),
    );
  }
}

/// Bordered block that groups one part of the sheet.
class AchievementInsetCard extends StatelessWidget {
  const AchievementInsetCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceVariant.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border.withValues(alpha: 0.55)),
      ),
      child: child,
    );
  }
}

/// The one progress block of the sheet: a label ("Racha" or "Progreso"), the
/// big "1 de 4" with its unit and a bar in the app accent.
///
/// The bar reveals when the sheet opens; when [current] changes while it is
/// open the number rolls and the bar grows.
class AchievementProgressBlock extends StatelessWidget {
  const AchievementProgressBlock({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    this.unit,
  });

  final String label;
  final int current;
  final int target;

  /// Already translated and in the right number ("semanas"); null = none.
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final fraction = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    final big = TextStyle(
      fontSize: SacFontSize.displayMedium,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.1,
      color: c.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return AchievementInsetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: SacFontSize.labelSmall,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SacRollingNumber(
                value: current,
                suffix: ' ${'achievements.views.summary_of'.tr(
                  namedArgs: {'total': '$target'},
                )}',
                style: big,
              ),
              if (unit != null && unit!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  unit!,
                  style: TextStyle(
                    fontSize: SacFontSize.titleSmall,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _RevealBar(value: fraction, color: SacAccent.of(context).color),
        ],
      ),
    );
  }
}

/// Bar that fills from empty on first build and eases to any later value.
class _RevealBar extends StatelessWidget {
  const _RevealBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: reduce ? Duration.zero : SacMotion.reveal,
      curve: SacMotion.easeOut,
      builder: (context, shown, _) => ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        child: LinearProgressIndicator(
          value: shown,
          minHeight: 6,
          color: color,
          backgroundColor: context.sac.border,
        ),
      ),
    );
  }
}

/// Items of a collection achievement and which ones are already collected.
class AchievementCollectionContent extends StatelessWidget {
  const AchievementCollectionContent({
    super.key,
    required this.achievement,
    this.userAchievement,
  });

  final Achievement achievement;
  final UserAchievement? userAchievement;

  @override
  Widget build(BuildContext context) {
    final requiredItems =
        (achievement.criteria['items'] as List<dynamic>?)?.cast<String>() ?? [];
    final collectedItems =
        (userAchievement?.progressMetadata?['collected'] as List<dynamic>?)
                ?.cast<String>() ??
            [];

    if (requiredItems.isEmpty) return const SizedBox.shrink();

    final c = context.sac;

    return AchievementInsetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'achievements.views.detail_collection'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 10),
          ...requiredItems.map((item) {
            final isCollected = collectedItems.contains(item);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  HugeIcon(
                    icon: isCollected
                        ? HugeIcons.strokeRoundedCheckmarkCircle02
                        : HugeIcons.strokeRoundedCircle,
                    size: 18,
                    color: isCollected ? c.success : c.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        fontWeight:
                            isCollected ? FontWeight.w600 : FontWeight.w400,
                        color: isCollected ? c.text : c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
