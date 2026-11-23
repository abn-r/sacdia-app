import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../animations/motion_tokens.dart';
import '../theme/app_theme.dart';
import '../theme/sac_accent.dart';
import '../theme/sac_colors.dart';
import '../utils/icon_helper.dart';
import 'sac_pressable.dart';

/// One row inside a [SacGroupedSection]: a leading avatar or icon, a title,
/// one line under it and a chevron when it opens something.
class SacListRow extends StatelessWidget {
  const SacListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.subtitleSpans,
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
                  if (subtitleSpans != null && subtitleSpans!.isNotEmpty) ...[
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

/// Square icon tile in the accent tone (or in red for a destructive row).
class SacListRowIcon extends StatelessWidget {
  const SacListRowIcon(this.icon, {super.key, this.destructive = false});

  final HugeIconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: destructive ? c.errorContainer : accent.light,
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
      child: HugeIcon(
        icon: icon,
        size: 19,
        color: destructive ? c.onErrorContainer : accent.color,
      ),
    );
  }
}
