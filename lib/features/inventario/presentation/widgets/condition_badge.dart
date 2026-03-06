import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/inventory_item.dart';

/// Badge de color que indica el estado de conservación del ítem.
class ConditionBadge extends StatelessWidget {
  final ItemCondition condition;
  final bool compact;

  const ConditionBadge({
    super.key,
    required this.condition,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _conditionColor(condition);
    final bg = color.withValues(alpha: 0.12);
    final label = compact ? condition.shortLabel : condition.label;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Color _conditionColor(ItemCondition condition) {
    switch (condition) {
      case ItemCondition.bueno:
        return AppColors.secondary;
      case ItemCondition.regular:
        return AppColors.accent;
      case ItemCondition.malo:
        return AppColors.error;
    }
  }
}
