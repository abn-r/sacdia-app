import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// One row of a grouped section in the activity detail: neutral icon tile,
/// title, an optional line under it, an optional [extra] block (class logos)
/// and, when it is tappable, a chevron (or [trailing]). Dividers of the
/// parent section are indented 58 to clear the tile.
class ActivityDetailRow extends StatelessWidget {
  const ActivityDetailRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.detail,
    this.extra,
    this.trailing,
    this.onTap,
  });

  /// Icon of the neutral tile. Ignored when [leading] is given.
  final HugeIconData? icon;

  /// Replaces the icon tile (an avatar). Keep it 32 wide so the dividers of
  /// the parent section line up.
  final Widget? leading;
  final String title;
  final String? detail;
  final Widget? extra;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final detail = this.detail;
    final end = trailing ??
        (onTap == null
            ? null
            : HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: c.textTertiary,
              ));

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            leading ??
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: ExcludeSemantics(
                    child: HugeIcon(
                      icon: icon!,
                      size: 17,
                      color: c.textSecondary,
                    ),
                  ),
                ),
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
                      height: 1.25,
                      color: c.text,
                    ),
                  ),
                  if (detail != null && detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.35,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                  if (extra != null) ...[
                    const SizedBox(height: 8),
                    extra!,
                  ],
                ],
              ),
            ),
            if (end != null) ...[const SizedBox(width: 8), end],
          ],
        ),
      ),
    );

    if (onTap == null) return content;
    return SacInkWell(
      onTap: onTap,
      pressedScale: SacMotion.rowPressScale,
      child: content,
    );
  }
}

/// Small uppercase label above a free block (the description), aligned with
/// the eyebrow of a grouped section. Place it in a column padded 20.
class ActivityEyebrow extends StatelessWidget {
  const ActivityEyebrow(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: context.sac.textTertiary,
        ),
      ),
    );
  }
}
