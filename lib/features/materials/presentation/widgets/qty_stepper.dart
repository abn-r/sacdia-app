import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';

/// Stepper de cantidad − / qty / + con límites [min] y [max].
class QtyStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const QtyStepper({
    super.key,
    required this.value,
    this.min = 1,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > min;
    final canIncrement = value < max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: HugeIcons.strokeRoundedMinusSign,
          enabled: canDecrement,
          onTap: canDecrement ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 40,
          child: Center(
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        _StepButton(
          icon: HugeIcons.strokeRoundedAdd01,
          enabled: canIncrement,
          onTap: canIncrement ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final HugeIconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primary : AppColors.lightTextTertiary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primaryLight : AppColors.lightBorder,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: HugeIcon(icon: icon, size: 18, color: color),
      ),
    );
  }
}
