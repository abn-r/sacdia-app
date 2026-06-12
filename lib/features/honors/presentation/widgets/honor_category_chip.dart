import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Horizontal category filter chip for the honors catalog.
///
/// Active state: solid sacBlue background with white text.
/// Inactive state: surfaceVariant background with textSecondary text (theme-aware).
/// No icons, no emojis — text only per design spec.
class HonorCategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;
  final Color? activeBorderColor;

  const HonorCategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
    this.activeBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = activeColor ?? AppColors.info;
    final activeColorIsLight =
        ThemeData.estimateBrightnessForColor(chipColor) == Brightness.light;
    final activeTextColor =
        activeColorIsLight ? context.sac.text : Colors.white;
    final borderColor = isSelected
        ? activeBorderColor ??
            (activeColorIsLight ? context.sac.border : Colors.transparent)
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 1.2 : 0),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? activeTextColor : context.sac.textSecondary,
          ),
        ),
      ),
    );
  }
}
