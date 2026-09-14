import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// Interactive filter pill. Selected = filled primary. Status labels use
/// [SacBadge] instead — do not mix the two in the same row.
class SacFilterChip extends StatelessWidget {
  const SacFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final dynamic icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final fg = selected ? Colors.white : c.textSecondary;

    return SacPressable(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: count == null ? label : '$label $count',
      child: AnimatedContainer(
        duration: SacMotion.standard,
        curve: SacMotion.easeOut,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: selected ? AppColors.primary : c.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              HugeIcon(icon: icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
