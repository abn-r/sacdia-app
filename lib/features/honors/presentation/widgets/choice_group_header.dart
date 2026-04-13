import 'package:flutter/material.dart';

import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Badge-style header for a choice group requirement.
///
/// Displays "Completá N de M" with a running count of how many children
/// have been completed so far. Renders inline above the child list.
///
/// Example: "Completá 3 de 5  —  1 completado"
class ChoiceGroupHeader extends StatelessWidget {
  /// Minimum number of children required to complete the parent.
  final int choiceMin;

  /// Total number of child requirements under the parent.
  final int totalChildren;

  /// How many children are currently marked as completed (local state).
  final int completedChildren;

  const ChoiceGroupHeader({
    super.key,
    required this.choiceMin,
    required this.totalChildren,
    required this.completedChildren,
  });

  bool get _isSatisfied => completedChildren >= choiceMin;

  @override
  Widget build(BuildContext context) {
    final Color accentColor =
        _isSatisfied ? AppColors.secondary : AppColors.sacYellow;
    final Color bgColor = _isSatisfied
        ? AppColors.secondaryLight
        : AppColors.accentLight;

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isSatisfied
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: accentColor,
          ),
          const SizedBox(width: 6),
          Text(
            'Completá $choiceMin de $totalChildren',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isSatisfied
                  ? AppColors.secondaryDark
                  : AppColors.accentDark,
            ),
          ),
          if (completedChildren > 0) ...[
            // Vertical micro-divider
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 1,
              height: 12,
              color: accentColor.withValues(alpha: 0.4),
            ),
            Text(
              '$completedChildren completado${completedChildren == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.sac.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
