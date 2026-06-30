import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

/// Variantes del badge
enum SacBadgeVariant { primary, secondary, accent, error, neutral }

/// Badge/chip pill del design system SACDIA "Scout Vibrante"
///
/// Uso: estados, categorías, labels, contadores.
class SacBadge extends StatelessWidget {
  final String label;
  final dynamic icon;
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

  Color _backgroundColor(BuildContext context) {
    if (backgroundColor != null) return backgroundColor!;

    switch (variant) {
      case SacBadgeVariant.primary:
        return AppColors.primaryLight;
      case SacBadgeVariant.secondary:
        return AppColors.secondaryLight;
      case SacBadgeVariant.accent:
        return AppColors.accentLight;
      case SacBadgeVariant.error:
        return AppColors.errorLight;
      case SacBadgeVariant.neutral:
        return context.sac.surfaceVariant;
    }
  }

  Color _foregroundColor(BuildContext context) {
    if (foregroundColor != null) return foregroundColor!;

    switch (variant) {
      case SacBadgeVariant.primary:
        return AppColors.primaryDark;
      case SacBadgeVariant.secondary:
        return AppColors.secondaryDark;
      case SacBadgeVariant.accent:
        return AppColors.accentDark;
      case SacBadgeVariant.error:
        return AppColors.errorDark;
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            buildIcon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fg,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
