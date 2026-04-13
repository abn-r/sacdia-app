import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_section.dart';

/// Timeline horizontal del flujo de estados de una sección:
/// Pendiente → Enviado → Validado → En evaluación → Evaluado.
///
/// Muestra los pasos como círculos conectados por líneas horizontales,
/// con etiquetas debajo de cada dot. Solo el paso activo muestra el sublabel.
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

    final showEvaluation = _hasEvaluationStep;

    final steps = [
      _TimelineStep(
        label: 'Pendiente',
        sublabel: 'En espera de evidencias',
        icon: HugeIcons.strokeRoundedClock01,
        isCompleted: true,
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

    // The dot diameter used throughout the layout.
    const double dotSize = 28.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length * 2 - 1, (index) {
          // Even indices → step nodes; odd indices → connecting lines.
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            final step = steps[stepIndex];
            // Expanded connector fills available space between steps.
            return Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: dotSize,
                    child: Center(
                      child: Container(
                        height: 2,
                        color: step.isCompleted
                            ? step.activeColor
                            : context.sac.border,
                      ),
                    ),
                  ),
                  // Empty space below to match label area height.
                  const SizedBox(height: 4 + 14 + 2 + 11),
                ],
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final step = steps[stepIndex];
          final c = context.sac;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Dot
              Container(
                width: dotSize,
                height: dotSize,
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
                    size: 14,
                    color: step.isCompleted || step.isActive
                        ? Colors.white
                        : c.textTertiary,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Main label
              Text(
                step.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: step.isActive
                      ? step.activeColor
                      : step.isCompleted
                          ? step.activeColor.withValues(alpha: 0.8)
                          : c.textTertiary,
                ),
              ),

              // Sublabel — only visible for the active step
              if (step.isActive) ...[
                const SizedBox(height: 2),
                Text(
                  step.sublabel,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ],
          );
        }),
      ),
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
