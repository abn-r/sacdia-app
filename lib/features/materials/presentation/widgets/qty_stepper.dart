import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

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
          semanticLabel: 'common.decrease_quantity'.tr(),
          enabled: canDecrement,
          onTap: canDecrement ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 40,
          child: Center(
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: SacFontSize.titleMedium,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        _StepButton(
          icon: HugeIcons.strokeRoundedAdd01,
          enabled: canIncrement,
          semanticLabel: 'common.increase_quantity'.tr(),
          onTap: canIncrement ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final HugeIconData icon;
  final bool enabled;
  final String? semanticLabel;
  final VoidCallback? onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final color = enabled ? SacAccent.of(context).color : c.textTertiary;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: enabled ? SacAccent.of(context).light : c.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              ),
              alignment: Alignment.center,
              child: HugeIcon(icon: icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
