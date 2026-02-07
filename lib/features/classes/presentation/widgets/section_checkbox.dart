import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/class_section.dart';

/// Widget de checkbox para sección de clase
class SectionCheckbox extends StatelessWidget {
  final ClassSection section;
  final Function(bool isCompleted) onChanged;

  const SectionCheckbox({
    Key? key,
    required this.section,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Checkbox(
        value: section.isCompleted,
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
        activeColor: AppColors.success,
      ),
      title: Text(
        section.name,
        style: TextStyle(
          fontSize: 14,
          decoration: section.isCompleted ? TextDecoration.lineThrough : null,
          color: section.isCompleted
              ? AppColors.lightTextSecondary
              : AppColors.lightText,
        ),
      ),
      onTap: () {
        onChanged(!section.isCompleted);
      },
    );
  }
}
