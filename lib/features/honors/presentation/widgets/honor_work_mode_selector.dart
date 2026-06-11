import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';

/// Selector explícito del camino de trabajo de una especialidad inscrita.
///
/// Se muestra únicamente cuando el backend indica `UNDECIDED`. La app no debe
/// mezclar checklist dentro de la app con formato externo en la misma CTA.
class HonorWorkModeSelector extends StatelessWidget {
  final Color categoryColor;
  final bool isLoading;
  final ValueChanged<HonorCompletionMode> onSelected;

  const HonorWorkModeSelector({
    super.key,
    required this.categoryColor,
    required this.onSelected,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedRoute01,
                  color: categoryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'honors.work_mode.title'.tr(),
                      style: TextStyle(
                        color: context.sac.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'honors.work_mode.subtitle'.tr(),
                      style: TextStyle(
                        color: context.sac.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ModeOptionCard(
            title: 'honors.work_mode.in_app_title'.tr(),
            description: 'honors.work_mode.in_app_description'.tr(),
            icon: HugeIcons.strokeRoundedTaskEdit01,
            categoryColor: categoryColor,
            isLoading: isLoading,
            onTap: () => onSelected(HonorCompletionMode.inApp),
          ),
          const SizedBox(height: 10),
          _ModeOptionCard(
            title: 'honors.work_mode.external_title'.tr(),
            description: 'honors.work_mode.external_description'.tr(),
            icon: HugeIcons.strokeRoundedPdf01,
            categoryColor: categoryColor,
            isLoading: isLoading,
            onTap: () => onSelected(HonorCompletionMode.external),
          ),
          if (isLoading) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'honors.work_mode.saving'.tr(),
                  style: TextStyle(
                    color: context.sac.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final HugeIconData icon;
  final Color categoryColor;
  final bool isLoading;
  final VoidCallback onTap;

  const _ModeOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.categoryColor,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !isLoading,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isLoading ? null : onTap,
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: categoryColor.withValues(alpha: 0.22),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: icon,
                    color: categoryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.sac.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: context.sac.textSecondary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: categoryColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
