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

  const SacBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = SacBadgeVariant.primary,
  });

  /// Success badge shortcut
  const SacBadge.success({super.key, required this.label, this.icon})
      : variant = SacBadgeVariant.secondary;

  /// Warning badge shortcut
  const SacBadge.warning({super.key, required this.label, this.icon})
      : variant = SacBadgeVariant.accent;

  /// Error badge shortcut
  const SacBadge.error({super.key, required this.label, this.icon})
      : variant = SacBadgeVariant.error;

  Color _backgroundColor(BuildContext context) {
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
            buildIcon(icon, size: 14, color: _foregroundColor(context)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _foregroundColor(context),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
