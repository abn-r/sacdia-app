import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_section.dart';

/// Timeline visual del flujo de estados de una sección:
/// Pendiente → Enviado → Validado → En evaluación → Evaluado.
///
/// Cada paso muestra nombre, fecha (si aplica) y actor (si aplica).
class StatusTimeline extends StatelessWidget {
  final EvidenceSectionStatus currentStatus;
  final String? submittedByName;
  final DateTime? submittedAt;
  final String? validatedByName;
  final DateTime? validatedAt;
  final String? evaluatedByName;
  final DateTime? evaluatedAt;
  final String? evaluationNotes;

  const StatusTimeline({
    super.key,
    required this.currentStatus,
    this.submittedByName,
    this.submittedAt,
    this.validatedByName,
    this.validatedAt,
    this.evaluatedByName,
    this.evaluatedAt,
    this.evaluationNotes,
  });

  bool get _hasEvaluationStep =>
      currentStatus == EvidenceSectionStatus.underEvaluation ||
      currentStatus == EvidenceSectionStatus.evaluated ||
      evaluatedByName != null ||
      evaluatedAt != null;

  bool get _isRejected => currentStatus == EvidenceSectionStatus.rechazado;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'es');

    // Determinar si los pasos "evaluación" aplican para este flujo.
    // Solo se muestran cuando la sección ya pasó a ese estado o tiene datos de
    // evaluación; evita mostrar pasos vacíos en el flujo normal.
    final showEvaluation = _hasEvaluationStep;

    final steps = [
      _TimelineStep(
        label: 'Pendiente',
        sublabel: 'En espera de evidencias',
        icon: HugeIcons.strokeRoundedClock01,
        isCompleted: true, // siempre fue pendiente alguna vez
        isActive: currentStatus == EvidenceSectionStatus.pendiente,
        activeColor: AppColors.accent,
      ),
      _TimelineStep(
        label: 'Enviado',
        sublabel: submittedByName != null && submittedAt != null
            ? 'Por $submittedByName · ${dateFormat.format(submittedAt!.toLocal())}'
            : submittedByName != null
                ? 'Por $submittedByName'
                : 'Esperando envío',
        icon: HugeIcons.strokeRoundedSent,
        isCompleted: currentStatus == EvidenceSectionStatus.enviado ||
            currentStatus == EvidenceSectionStatus.validado ||
            currentStatus == EvidenceSectionStatus.rechazado ||
            currentStatus == EvidenceSectionStatus.underEvaluation ||
            currentStatus == EvidenceSectionStatus.evaluated,
        isActive: currentStatus == EvidenceSectionStatus.enviado,
        activeColor: AppColors.sacBlue,
      ),
      if (_isRejected)
        _TimelineStep(
          label: 'Rechazado',
          sublabel: validatedByName != null
              ? 'Por $validatedByName'
              : 'Sección rechazada',
          icon: HugeIcons.strokeRoundedCancel01,
          isCompleted: true,
          isActive: true,
          activeColor: AppColors.error,
        )
      else ...[
        _TimelineStep(
          label: 'Validado',
          sublabel: validatedByName != null && validatedAt != null
              ? 'Por $validatedByName · ${dateFormat.format(validatedAt!.toLocal())}'
              : validatedByName != null
                  ? 'Por $validatedByName'
                  : 'Esperando validación',
          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
          isCompleted: currentStatus == EvidenceSectionStatus.validado ||
              currentStatus == EvidenceSectionStatus.underEvaluation ||
              currentStatus == EvidenceSectionStatus.evaluated,
          isActive: currentStatus == EvidenceSectionStatus.validado,
          activeColor: AppColors.secondary,
        ),
      ],
      if (!_isRejected && showEvaluation) ...[
        _TimelineStep(
          label: 'En evaluación',
          sublabel: 'Revisión de puntuación por el evaluador',
          icon: HugeIcons.strokeRoundedAnalytics01,
          isCompleted: currentStatus == EvidenceSectionStatus.underEvaluation ||
              currentStatus == EvidenceSectionStatus.evaluated,
          isActive: currentStatus == EvidenceSectionStatus.underEvaluation,
          activeColor: const Color(0xFFF59E0B),
        ),
        _TimelineStep(
          label: 'Evaluado',
          sublabel: _buildEvaluatedSublabel(dateFormat),
          icon: HugeIcons.strokeRoundedStar,
          isCompleted: currentStatus == EvidenceSectionStatus.evaluated,
          isActive: currentStatus == EvidenceSectionStatus.evaluated,
          activeColor: AppColors.secondaryDark,
        ),
      ],
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dot + vertical line
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
                padding: EdgeInsets.only(
                    top: 6, bottom: isLast ? 0 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: step.isActive
                                    ? step.activeColor
                                    : step.isCompleted
                                        ? step.activeColor.withValues(
                                            alpha: 0.8)
                                        : c.textTertiary,
                              ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.sublabel,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
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

  String _buildEvaluatedSublabel(DateFormat dateFormat) {
    if (evaluatedByName != null && evaluatedAt != null) {
      return 'Por $evaluatedByName · ${dateFormat.format(evaluatedAt!.toLocal())}';
    }
    if (evaluatedByName != null) return 'Por $evaluatedByName';
    if (evaluatedAt != null) {
      return 'El ${dateFormat.format(evaluatedAt!.toLocal())}';
    }
    return 'Evaluación completada';
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
