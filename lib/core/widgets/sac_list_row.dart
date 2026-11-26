import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../animations/motion_tokens.dart';
import '../theme/app_theme.dart';
import '../theme/sac_colors.dart';
import '../utils/icon_helper.dart';
import 'sac_pressable.dart';
import 'sac_tone.dart';

/// One row inside a [SacGroupedSection]: a leading avatar or icon, a title,
/// one line under it and a chevron when it opens something.
class SacListRow extends StatelessWidget {
  const SacListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.subtitleSpans,
    this.subtitleWidget,
    this.subtitleColor,
    this.titleColor,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.showChevron = true,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// Subtitle in parts, when one part needs its own color. Wins over
  /// [subtitle].
  final List<TextSpan>? subtitleSpans;

  /// Free-form second line (icon plus text, a loading bone). Wins over
  /// [subtitleSpans] and [subtitle]; the caller owns its style.
  final Widget? subtitleWidget;
  final Color? subtitleColor;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? c.text,
                    ),
                  ),
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: 2),
                    subtitleWidget!,
                  ] else if (subtitleSpans != null &&
                      subtitleSpans!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: subtitleSpans),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        height: 1.3,
                        color: subtitleColor ?? c.textSecondary,
                      ),
                    ),
                  ] else if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        height: 1.3,
                        color: subtitleColor ?? c.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (onTap != null && showChevron) ...[
              const SizedBox(width: 4),
              ExcludeSemantics(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final body = Opacity(
      opacity: enabled ? 1 : AppTheme.disabledOpacity,
      child: row,
    );
    if (onTap == null) return MergeSemantics(child: body);
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: SacInkWell(
          onTap: enabled ? onTap : null,
          pressedScale: SacMotion.rowPressScale,
          child: body,
        ),
      ),
    );
  }
}

/// Square icon tile tinted by [tone] (accent by default, or red for a
/// destructive row).
class SacListRowIcon extends StatelessWidget {
  const SacListRowIcon(
    this.icon, {
    super.key,
    this.destructive = false,
    this.tone = SacTone.accent,
  });

  final HugeIconData icon;

  /// Same as `tone: SacTone.error`; wins over [tone].
  final bool destructive;
  final SacTone tone;

  @override
  Widget build(BuildContext context) {
    final palette =
        SacTonePalette.of(context, destructive ? SacTone.error : tone);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.container,
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
      child: HugeIcon(icon: icon, size: 19, color: palette.onContainer),
    );
  }
}
