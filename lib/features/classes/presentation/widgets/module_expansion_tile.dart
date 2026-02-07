import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/class_module.dart';
import 'section_checkbox.dart';

/// Widget de módulo expandible con secciones
class ModuleExpansionTile extends StatelessWidget {
  final ClassModule module;
  final Function(int sectionId, bool isCompleted) onSectionToggle;

  const ModuleExpansionTile({
    Key? key,
    required this.module,
    required this.onSectionToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final completedCount = module.sections.where((s) => s.isCompleted).length;
    final totalCount = module.sections.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
          child: Text(
            '$completedCount/$totalCount',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        title: Text(
          module.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '$completedCount de $totalCount completadas',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.lightTextSecondary,
          ),
        ),
        children: module.sections.map((section) {
          return SectionCheckbox(
            section: section,
            onChanged: (isCompleted) {
              onSectionToggle(section.id, isCompleted);
            },
          );
        }).toList(),
      ),
    );
  }
}
