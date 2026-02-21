import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

import '../../domain/entities/class_section.dart';

/// Checkbox circular de sección - Estilo "Scout Vibrante"
///
/// Completado: check emerald + texto tachado sutil.
/// Pendiente: círculo vacío + texto normal.
class SectionCheckbox extends StatelessWidget {
  final ClassSection section;
  final Function(bool isCompleted) onChanged;

  const SectionCheckbox({
    super.key,
    required this.section,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!section.isCompleted),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // Circular checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: section.isCompleted
                    ? AppColors.secondary
                    : Colors.transparent,
                border: Border.all(
                  color: section.isCompleted
                      ? AppColors.secondary
                      : AppColors.lightBorder,
                  width: 2,
                ),
              ),
              child: section.isCompleted
                  ? HugeIcon(icon: HugeIcons.strokeRoundedTick02,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),

            // Section name
            Expanded(
              child: Text(
                section.name,
                style: TextStyle(
                  fontSize: 14,
                  decoration:
                      section.isCompleted ? TextDecoration.lineThrough : null,
                  color: section.isCompleted
                      ? AppColors.lightTextTertiary
                      : AppColors.lightText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
