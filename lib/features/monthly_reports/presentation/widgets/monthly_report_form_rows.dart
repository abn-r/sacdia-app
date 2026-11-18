import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/features/materials/presentation/widgets/qty_stepper.dart';

/// Máximo de un contador: los datos del informe son conteos del mes.
const int kMonthlyReportCounterMax = 999;

/// Un conteo chico con − y + (sin teclado). [previousHint] es el valor del mes
/// anterior en gris ("oct: 4") cuando se conoce.
class MonthlyReportStepperRow extends StatelessWidget {
  const MonthlyReportStepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.previousHint,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String? previousHint;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hint = previousHint;

    return Semantics(
      container: true,
      label: '$label, $value',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      height: 1.25,
                      color: c.text,
                    ),
                  ),
                ),
              ),
              if (hint != null) ...[
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: Text(
                    hint,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textTertiary,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              QtyStepper(
                value: value,
                min: 0,
                max: kMonthlyReportCounterMax,
                onChanged: (next) {
                  HapticFeedback.selectionClick();
                  onChanged(next);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un sí/no como interruptor.
class MonthlyReportSwitchRow extends StatelessWidget {
  const MonthlyReportSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Semantics(
      container: true,
      toggled: value,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      height: 1.25,
                      color: c.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SacPressable(
                listenOnly: true,
                child: Switch.adaptive(
                  value: value,
                  activeThumbColor: SacAccent.of(context).color,
                  onChanged: (next) {
                    HapticFeedback.selectionClick();
                    onChanged(next);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
