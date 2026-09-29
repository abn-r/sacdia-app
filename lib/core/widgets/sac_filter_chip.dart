import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

enum SacFilterChipVariant { filled, quiet }

/// Interactive filter pill. Filled selected = solid primary. Quiet selected =
/// primaryLight + primaryDark (not color-only). Status labels use [SacBadge].
class SacFilterChip extends StatelessWidget {
  const SacFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.logoAsset,
    this.accentBackground,
    this.accentForeground,
    this.count,
    this.variant = SacFilterChipVariant.filled,
  });

  /// Compact pill height. Horizontal filter rows should use [barHeight].
  static const double minHeight = 28;

  /// Apple HIG / WCAG touch target. Visual pill stays [minHeight].
  static const double hitExtent = 44;

  /// Row track for a horizontal [ListView] of chips.
  static const double barHeight = hitExtent;

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final dynamic icon;
  final String? logoAsset;
  final Color? accentBackground;
  final Color? accentForeground;
  final int? count;
  final SacFilterChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final colorDuration = reduce ? SacMotion.reducedFade : SacMotion.standard;
    final quiet = variant == SacFilterChipVariant.quiet;
    final accent = SacAccent.of(context);
    final Color bg;
    final Color fg;
    final Color border;

    if (quiet && selected) {
      bg = accentBackground ?? accent.light;
      fg = accentForeground ?? accent.dark;
      border = fg;
    } else if (selected) {
      bg = accent.color;
      fg = accent.onColor;
      border = accent.color;
    } else if (accentForeground != null) {
      bg = c.surface;
      fg = accentForeground!;
      border = accentForeground!.withValues(alpha: 0.45);
    } else {
      bg = c.surface;
      fg = c.textSecondary;
      border = c.border;
    }

    return Semantics(
      selected: selected,
      child: SacPressable(
        onTap: onTap,
        enabled: onTap != null,
        semanticLabel: count == null ? label : '$label $count',
        child: SizedBox(
          height: hitExtent,
          child: Center(
            widthFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: hitExtent),
              child: AnimatedContainer(
                duration: colorDuration,
                curve: SacMotion.easeOut,
                constraints: const BoxConstraints(minHeight: minHeight),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (logoAsset != null) ...[
                      Image.asset(
                        logoAsset!,
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: 48,
                        cacheHeight: 48,
                        errorBuilder: (_, __, ___) => HugeIcon(
                          icon: HugeIcons.strokeRoundedUserGroup,
                          size: 13,
                          color: fg,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ] else if (icon != null) ...[
                      TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: fg),
                        duration: colorDuration,
                        curve: SacMotion.easeOut,
                        builder: (context, color, _) => HugeIcon(
                          icon: icon,
                          size: 13,
                          color: color ?? fg,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    AnimatedDefaultTextStyle(
                      duration: colorDuration,
                      curve: SacMotion.easeOut,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 5),
                      AnimatedDefaultTextStyle(
                        duration: colorDuration,
                        curve: SacMotion.easeOut,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: fg.withValues(alpha: 0.85),
                        ),
                        child: Text('$count'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
