import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/class_section.dart';

/// Checkbox circular de sección - Estilo "Scout Vibrante"
///
/// Completado: check emerald + texto tachado sutil.
/// Pendiente: círculo vacío + texto normal.
class SectionCheckbox extends StatefulWidget {
  final ClassSection section;
  final Function(bool isCompleted) onChanged;

  const SectionCheckbox({
    super.key,
    required this.section,
    required this.onChanged,
  });

  @override
  State<SectionCheckbox> createState() => _SectionCheckboxState();
}

class _SectionCheckboxState extends State<SectionCheckbox> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final completed = section.isCompleted;
    final reduce = SacMotion.reduceMotionOf(context);
    final fill = completed ? AppColors.secondary : Colors.transparent;
    final border = completed ? AppColors.secondary : context.sac.border;
    final labelColor = completed ? context.sac.textTertiary : context.sac.text;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!completed),
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              AnimatedScale(
                scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
                duration: SacMotion.press,
                curve: SacMotion.easeOut,
                child: AnimatedContainer(
                  duration: reduce ? SacMotion.reducedFade : SacMotion.standard,
                  curve: SacMotion.easeOut,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                    border: Border.all(color: border, width: 2),
                  ),
                  child: SacStateSwap(
                    duration: SacMotion.press,
                    child: completed
                        ? const HugeIcon(
                            key: ValueKey('section-check-on'),
                            icon: HugeIcons.strokeRoundedTick02,
                            size: 14,
                            color: Colors.white,
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('section-check-off'),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: reduce ? SacMotion.reducedFade : SacMotion.press,
                  curve: SacMotion.easeOut,
                  style: TextStyle(
                    fontSize: 14,
                    decoration: completed ? TextDecoration.lineThrough : null,
                    color: labelColor,
                  ),
                  child: Text(section.name),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
