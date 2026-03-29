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
            ? 'Por $submittedByName · ${dateFormat.format(submittedAt!.toLocal())}'
            : submittedByName != null
                ? 'Por $submittedByName'
                : 'Esperando envio del miembro',
        icon: HugeIcons.strokeRoundedSent,
        isCompleted: currentStatus == RequirementStatus.enviado ||
            currentStatus == RequirementStatus.validado ||
            currentStatus == RequirementStatus.rechazado,
        isActive: currentStatus == RequirementStatus.enviado,
        activeColor: AppColors.sacBlue,
      ),
      if (currentStatus == RequirementStatus.rechazado)
        _TimelineStep(
          label: 'Rechazado',
          sublabel: validatedByName != null
              ? 'Por $validatedByName'
              : 'Requerimiento rechazado',
          icon: HugeIcons.strokeRoundedCancel01,
          isCompleted: true,
          isActive: true,
          activeColor: AppColors.error,
        )
      else
        _TimelineStep(
          label: 'Validado',
          sublabel: validatedByName != null && validatedAt != null
              ? 'Por $validatedByName · ${dateFormat.format(validatedAt!.toLocal())}'
              : validatedByName != null
                  ? 'Por $validatedByName'
                  : 'Esperando validacion del lider',
          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
          isCompleted: currentStatus == RequirementStatus.validado,
          isActive: currentStatus == RequirementStatus.validado,
          activeColor: AppColors.secondary,
        ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          // Step column: circle + label + sublabel
          _buildStep(context, steps[i], c),

          // Connecting line between steps (not after the last one)
          if (i < steps.length - 1)
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Container(
                    height: 2,
                    color: steps[i].isCompleted
                        ? steps[i].activeColor
                        : c.border,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildStep(
    BuildContext context,
    _TimelineStep step,
    SacColors c,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circle with icon
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
          child: Center(
            child: HugeIcon(
              icon: step.icon,
              size: 16,
              color: step.isCompleted || step.isActive
                  ? Colors.white
                  : c.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Label
        Text(
          step.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: step.isActive
                    ? step.activeColor
                    : step.isCompleted
                        ? step.activeColor.withValues(alpha: 0.8)
                        : c.textTertiary,
              ),
        ),
        const SizedBox(height: 2),

        // Sublabel
        SizedBox(
          width: 80,
          child: Text(
            step.sublabel,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: c.textSecondary,
                  height: 1.3,
                ),
          ),
        ),
      ],
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
