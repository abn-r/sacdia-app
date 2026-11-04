import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Variantes del badge
enum SacBadgeVariant { primary, secondary, accent, error, info, neutral }

/// Badge/chip pill del design system SACDIA "Scout Vibrante"
///
/// Uso: estados, categorías, labels, contadores.
class SacBadge extends StatelessWidget {
  final String label;
  final HugeIconData? icon;
  final SacBadgeVariant variant;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const SacBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = SacBadgeVariant.primary,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Success badge shortcut
  const SacBadge.success({super.key, required this.label, this.icon})
      : variant = SacBadgeVariant.secondary,
        backgroundColor = null,
        foregroundColor = null;

  /// Warning badge shortcut
  const SacBadge.warning({super.key, required this.label, this.icon})
      : variant = SacBadgeVariant.accent,
        backgroundColor = null,
        foregroundColor = null;

  /// Error badge shortcut
  const SacBadge.error({super.key, required this.label, this.icon})
      : variant = SacBadgeVariant.error,
        backgroundColor = null,
        foregroundColor = null;

  /// Info badge shortcut
  const SacBadge.info({super.key, required this.label, this.icon})
      : variant = SacBadgeVariant.info,
        backgroundColor = null,
        foregroundColor = null;

  Color _backgroundColor(BuildContext context) {
    if (backgroundColor != null) return backgroundColor!;

    switch (variant) {
      case SacBadgeVariant.primary:
        final accent = SacAccent.of(context);
        if (Theme.of(context).brightness == Brightness.dark) {
          // Accent tint over the dark surface, not over white.
          return Color.alphaBlend(
            accent.color.withValues(alpha: 0.2),
            context.sac.surface,
          );
        }
        return accent.light;
      case SacBadgeVariant.secondary:
        return context.sac.successContainer;
      case SacBadgeVariant.accent:
        return context.sac.warningContainer;
      case SacBadgeVariant.error:
        return context.sac.errorContainer;
      case SacBadgeVariant.info:
        return context.sac.infoContainer;
      case SacBadgeVariant.neutral:
        return context.sac.surfaceVariant;
    }
  }

  Color _foregroundColor(BuildContext context) {
    if (foregroundColor != null) return foregroundColor!;

    switch (variant) {
      case SacBadgeVariant.primary:
        final accent = SacAccent.of(context);
        if (Theme.of(context).brightness == Brightness.dark) {
          return accent.forHighContrast(Brightness.dark).color;
        }
        return accent.dark;
      case SacBadgeVariant.secondary:
        return context.sac.onSuccessContainer;
      case SacBadgeVariant.accent:
        return context.sac.onWarningContainer;
      case SacBadgeVariant.error:
        return context.sac.onErrorContainer;
      case SacBadgeVariant.info:
        return context.sac.onInfoContainer;
      case SacBadgeVariant.neutral:
        return context.sac.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _foregroundColor(context);

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 4,
        horizontal: icon != null ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            buildIcon(icon!, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          // Flexible: in a narrow slot (a card row with actions) the label
          // wraps instead of overflowing.
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                fontWeight: FontWeight.w500,
                color: fg,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
