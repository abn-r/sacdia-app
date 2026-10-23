import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sacdia_app/core/animations/animated_counter.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

/// Visual tone of a [SacStatTile]. It tints the icon (and the value for
/// [error]); it never replaces the label, so meaning is not color-only.
enum SacStatTone { neutral, warning, error, success, accent }

/// KPI tile: tinted icon circle, animated number and a label.
///
/// Built on [SacCard]. Use [SacStatTile.skeleton] while data loads; it has the
/// same layout so the screen does not jump when the numbers arrive.
///
/// Wrap a row of tiles in `IntrinsicHeight` + `CrossAxisAlignment.stretch` so
/// labels that wrap to two lines keep every tile the same height.
class SacStatTile extends StatelessWidget {
  const SacStatTile({
    super.key,
    required HugeIconData this.icon,
    required num this.value,
    required String this.label,
    this.tone = SacStatTone.neutral,
    this.decimals = 0,
    this.onTap,
    this.animate = false,
    this.animationDelay = Duration.zero,
  }) : _skeleton = false;

  /// Placeholder with the same layout as the real tile.
  const SacStatTile.skeleton({super.key})
      : icon = null,
        value = null,
        label = null,
        tone = SacStatTone.neutral,
        decimals = 0,
        onTap = null,
        animate = false,
        animationDelay = Duration.zero,
        _skeleton = true;

  final HugeIconData? icon;
  final num? value;
  final String? label;
  final SacStatTone tone;

  /// Fraction digits shown for [value] (e.g. 1 for "2.5"). The counter still
  /// animates; it counts in units of `10^-decimals`.
  final int decimals;
  final VoidCallback? onTap;

  /// Entrance animation (fade + scale) of the underlying [SacCard].
  final bool animate;
  final Duration animationDelay;
  final bool _skeleton;

  static const double _iconCircle = 36;
  static const EdgeInsets _padding = EdgeInsets.all(12);

  Color _toneColor(BuildContext context) {
    final c = context.sac;
    switch (tone) {
      case SacStatTone.neutral:
        return c.textSecondary;
      case SacStatTone.warning:
        return c.warning;
      case SacStatTone.error:
        return c.error;
      case SacStatTone.success:
        return c.success;
      case SacStatTone.accent:
        return SacAccent.of(context).color;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_skeleton) return const _StatTileSkeleton();

    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    final toneColor = _toneColor(context);
    final circleColor = tone == SacStatTone.neutral
        ? c.surfaceVariant
        : toneColor.withValues(alpha: 0.14);
    final scale = math.pow(10, decimals).toInt();
    final counterValue = (value! * scale).round();
    final valueColor = tone == SacStatTone.error ? c.error : c.text;
    final locale = Localizations.maybeLocaleOf(context)?.toString();

    return SacCard(
      padding: _padding,
      onTap: onTap,
      animate: animate,
      animationDelay: animationDelay,
      child: MergeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _iconCircle,
              height: _iconCircle,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: HugeIcon(icon: icon!, size: 18, color: toneColor),
            ),
            const SizedBox(height: 10),
            AnimatedCounter(
              value: counterValue,
              formatter: decimals == 0
                  ? null
                  : (v) => intl.NumberFormat.decimalPatternDigits(
                        locale: locale,
                        decimalDigits: decimals,
                      ).format(v / scale),
              style: theme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.labelMedium?.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTileSkeleton extends StatelessWidget {
  const _StatTileSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c.border,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return SacCard(
      padding: SacStatTile._padding,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: SacStatTile._iconCircle,
              height: SacStatTile._iconCircle,
              decoration:
                  BoxDecoration(color: c.border, shape: BoxShape.circle),
            ),
            const SizedBox(height: 10),
            bar(36, 22),
            const SizedBox(height: 6),
            bar(64, 12),
          ],
        ),
      ),
    );
  }
}
