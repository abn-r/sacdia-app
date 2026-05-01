import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_section.dart';

/// Timeline horizontal del flujo de estados de una sección:
/// Pendiente → Enviado → Preaprobado (LF) → Validado.
///
/// Muestra los pasos como círculos conectados por líneas horizontales,
/// con etiquetas debajo de cada dot. Solo el paso activo muestra el sublabel.
class StatusTimeline extends StatelessWidget {
  final EvidenceSectionStatus currentStatus;
  final String? submittedByName;
  final DateTime? submittedAt;
  final String? lfApproverName;
  final DateTime? lfApprovedAt;
  final String? unionApproverName;
  final DateTime? unionApprovedAt;
  final String? evaluationNotes;

  const StatusTimeline({
    super.key,
    required this.currentStatus,
    this.submittedByName,
    this.submittedAt,
    this.lfApproverName,
    this.lfApprovedAt,
    this.unionApproverName,
    this.unionApprovedAt,
    this.evaluationNotes,
  });

  bool get _hasPreapprovedStep =>
      currentStatus == EvidenceSectionStatus.preapprovedLf ||
      currentStatus == EvidenceSectionStatus.validated ||
      lfApproverName != null;

  bool get _isRejected => currentStatus == EvidenceSectionStatus.rejected;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'es');

    final showPreapproved = _hasPreapprovedStep;

    final steps = [
      _TimelineStep(
        label: 'evidence_folder.status.pending'.tr(),
        sublabel: 'evidence_folder.timeline.waiting_evidence'.tr(),
        icon: HugeIcons.strokeRoundedClock01,
        isCompleted: true,
        isActive: currentStatus == EvidenceSectionStatus.pending,
        activeColor: AppColors.accent,
      ),
      _TimelineStep(
        label: 'evidence_folder.status.submitted'.tr(),
        sublabel: submittedByName != null && submittedAt != null
            ? 'evidence_folder.trace.sent_by'.tr(namedArgs: {
                'name': submittedByName!,
                'date': ' · ${dateFormat.format(submittedAt!.toLocal())}',
              })
            : submittedByName != null
                ? 'evidence_folder.trace.sent_by'.tr(namedArgs: {
                    'name': submittedByName!,
                    'date': '',
                  })
                : 'evidence_folder.timeline.waiting_send'.tr(),
        icon: HugeIcons.strokeRoundedSent,
        isCompleted: currentStatus == EvidenceSectionStatus.submitted ||
            currentStatus == EvidenceSectionStatus.validated ||
            currentStatus == EvidenceSectionStatus.rejected ||
            currentStatus == EvidenceSectionStatus.preapprovedLf,
        isActive: currentStatus == EvidenceSectionStatus.submitted,
        activeColor: AppColors.sacBlue,
      ),
      if (_isRejected)
        _TimelineStep(
          label: 'evidence_folder.status.rejected'.tr(),
          sublabel: lfApproverName != null
              ? 'evidence_folder.trace.sent_by'.tr(namedArgs: {
                  'name': lfApproverName!,
                  'date': '',
                })
              : 'evidence_folder.timeline.rejected'.tr(),
          icon: HugeIcons.strokeRoundedCancel01,
          isCompleted: true,
          isActive: true,
          activeColor: AppColors.error,
        )
      else ...[
        if (!_isRejected && showPreapproved) ...[
          _TimelineStep(
            label: 'evidence_folder.status.preapproved'.tr(),
            sublabel: lfApproverName != null && lfApprovedAt != null
                ? 'evidence_folder.trace.preapproved_by'.tr(namedArgs: {
                    'name': lfApproverName!,
                    'date': ' · ${dateFormat.format(lfApprovedAt!.toLocal())}',
                  })
                : lfApproverName != null
                    ? 'evidence_folder.trace.preapproved_by'.tr(namedArgs: {
                        'name': lfApproverName!,
                        'date': '',
                      })
                    : 'evidence_folder.timeline.local_review'.tr(),
            icon: HugeIcons.strokeRoundedAnalytics01,
            isCompleted: currentStatus == EvidenceSectionStatus.preapprovedLf ||
                currentStatus == EvidenceSectionStatus.validated,
            isActive: currentStatus == EvidenceSectionStatus.preapprovedLf,
            activeColor: AppColors.accentDark,
          ),
        ],
        _TimelineStep(
          label: 'evidence_folder.status.validated'.tr(),
          sublabel: unionApproverName != null && unionApprovedAt != null
              ? 'evidence_folder.trace.validated_by'.tr(namedArgs: {
                  'name': unionApproverName!,
                  'date': ' · ${dateFormat.format(unionApprovedAt!.toLocal())}',
                })
              : unionApproverName != null
                  ? 'evidence_folder.trace.validated_by'.tr(namedArgs: {
                      'name': unionApproverName!,
                      'date': '',
                    })
                  : lfApproverName != null && !showPreapproved
                      ? 'evidence_folder.trace.validated_by'.tr(namedArgs: {
                          'name': lfApproverName!,
                          'date': '',
                        })
                      : 'evidence_folder.timeline.waiting_validation'.tr(),
          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
          isCompleted: currentStatus == EvidenceSectionStatus.validated,
          isActive: currentStatus == EvidenceSectionStatus.validated,
          activeColor: AppColors.secondary,
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
