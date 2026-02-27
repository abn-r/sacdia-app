import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/class_module.dart';
import 'section_checkbox.dart';

/// Módulo expandible - Estilo "Scout Vibrante"
///
/// SacCard con ExpansionTile, mini progress bar, badge "X/Y".
class ModuleExpansionTile extends StatelessWidget {
  final ClassModule module;
  final Function(int sectionId, bool isCompleted) onSectionToggle;

  const ModuleExpansionTile({
    super.key,
    required this.module,
    required this.onSectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = module.sections.where((s) => s.isCompleted).length;
    final totalCount = module.sections.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final isComplete = completedCount == totalCount && totalCount > 0;

    return SacCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isComplete
                  ? AppColors.secondaryLight
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isComplete
                  ? HugeIcon(icon: HugeIcons.strokeRoundedTick02,
                      size: 20, color: AppColors.secondaryDark)
                  : Text(
                      '$completedCount/$totalCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
            ),
          ),
          title: Text(
            module.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: context.sac.borderLight,
                color: isComplete ? AppColors.secondary : AppColors.primary,
              ),
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
      ),
    );
  }
}
