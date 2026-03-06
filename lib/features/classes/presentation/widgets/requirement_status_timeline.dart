import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/class_requirement.dart';

/// Timeline visual del flujo de estados de un requerimiento:
/// Pendiente -> Enviado -> Validado.
///
/// Identico al StatusTimeline de carpeta_evidencias pero tipado
/// para [RequirementStatus].
class RequirementStatusTimeline extends StatelessWidget {
  final RequirementStatus currentStatus;
  final String? submittedByName;
  final DateTime? submittedAt;
  final String? validatedByName;
  final DateTime? validatedAt;

  const RequirementStatusTimeline({
    super.key,
    required this.currentStatus,
    this.submittedByName,
    this.submittedAt,
    this.validatedByName,
    this.validatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'es');

    final steps = [
      _TimelineStep(
        label: 'Pendiente',
        sublabel: 'Esperando evidencias del miembro',
        icon: HugeIcons.strokeRoundedClock01,
        isCompleted: true,
        isActive: currentStatus == RequirementStatus.pendiente,
        activeColor: AppColors.accent,
      ),
      _TimelineStep(
        label: 'Enviado',
        sublabel: submittedByName != null && submittedAt != null
            ? 'Por $submittedByName · ${dateFormat.format(submittedAt!)}'
            : submittedByName != null
                ? 'Por $submittedByName'
                : 'Esperando envio del miembro',
        icon: HugeIcons.strokeRoundedSent,
        isCompleted: currentStatus == RequirementStatus.enviado ||
            currentStatus == RequirementStatus.validado,
        isActive: currentStatus == RequirementStatus.enviado,
        activeColor: AppColors.sacBlue,
      ),
      _TimelineStep(
        label: 'Validado',
        sublabel: validatedByName != null && validatedAt != null
            ? 'Por $validatedByName · ${dateFormat.format(validatedAt!)}'
            : validatedByName != null
                ? 'Por $validatedByName'
                : 'Esperando validacion del lider',
        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
        isCompleted: currentStatus == RequirementStatus.validado,
        isActive: currentStatus == RequirementStatus.validado,
        activeColor: AppColors.secondary,
      ),
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dot + linea vertical
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: step.isCompleted || step.isActive
                        ? step.activeColor
                        : c.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: step.isCompleted || step.isActive
                          ? step.activeColor
                          : c.border,
                      width: 2,
                    ),
                  ),
                  child: HugeIcon(
                    icon: step.icon,
                    size: 16,
                    color: step.isCompleted || step.isActive
                        ? Colors.white
                        : c.textTertiary,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    color: step.isCompleted ? step.activeColor : c.border,
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Labels
            Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(top: 6, bottom: isLast ? 0 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: step.isActive
                                ? step.activeColor
                                : step.isCompleted
                                    ? step.activeColor
                                        .withValues(alpha: 0.8)
                                    : c.textTertiary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.sublabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: c.textSecondary,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TimelineStep {
  final String label;
  final String sublabel;
  final List<List<dynamic>> icon;
  final bool isCompleted;
  final bool isActive;
  final Color activeColor;

  const _TimelineStep({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.isCompleted,
    required this.isActive,
    required this.activeColor,
  });
}
