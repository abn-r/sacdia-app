import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_status_history_sheet.dart';

import '../../domain/entities/evidence_section.dart';

/// Historial de transiciones de una sección de evidencias.
///
/// Los datos son snapshots de trazabilidad en [EvidenceSection]. La entrada
/// de validación de unión se omite si [EvidenceSection.unionApproverName]
/// es null. Llamar con [showEvidenceStatusHistorySheet].
class EvidenceStatusHistorySheet extends StatelessWidget {
  const EvidenceStatusHistorySheet({
    super.key,
    required this.section,
  });

  final EvidenceSection section;

  @override
  Widget build(BuildContext context) {
    return SacStatusHistorySheet(
      title: 'evidence_folder.status_history.title'.tr(),
      subtitle: section.name,
      entries: _evidenceStatusHistoryEntries(section),
      emptyTitle: 'evidence_folder.status_history.empty_title'.tr(),
      emptyBody: 'evidence_folder.status_history.empty_description'.tr(),
    );
  }
}

List<SacStatusHistoryEntry> _evidenceStatusHistoryEntries(
  EvidenceSection section,
) {
  final entries = <SacStatusHistoryEntry>[
    SacStatusHistoryEntry(
      label: 'evidence_folder.status.pending'.tr(),
      description: 'evidence_folder.status_history.pending_desc'.tr(),
      icon: HugeIcons.strokeRoundedClock01,
      color: AppColors.accent,
    ),
  ];

  final wasSubmitted = section.status == EvidenceSectionStatus.submitted ||
      section.status == EvidenceSectionStatus.validated ||
      section.status == EvidenceSectionStatus.rejected ||
      section.status == EvidenceSectionStatus.preapprovedLf;

  if (wasSubmitted) {
    entries.add(
      SacStatusHistoryEntry(
        label: 'evidence_folder.status.submitted'.tr(),
        description: 'evidence_folder.status_history.submitted_desc'.tr(),
        icon: HugeIcons.strokeRoundedSent,
        color: AppColors.info,
        author: section.submittedByName,
        timestamp: section.submittedAt,
      ),
    );
  }

  if (section.status == EvidenceSectionStatus.rejected) {
    entries.add(
      SacStatusHistoryEntry(
        label: 'evidence_folder.status.rejected'.tr(),
        description: 'evidence_folder.status_history.rejected_desc'.tr(),
        icon: HugeIcons.strokeRoundedCancel01,
        color: AppColors.error,
        author: section.lfApproverName ?? section.validatedByName,
        timestamp: section.lfApprovedAt ?? section.validatedAt,
      ),
    );
    return entries;
  }

  if (section.status == EvidenceSectionStatus.preapprovedLf ||
      section.status == EvidenceSectionStatus.validated) {
    entries.add(
      SacStatusHistoryEntry(
        label: 'evidence_folder.status.preapproved'.tr(),
        description: 'evidence_folder.status_history.preapproved_desc'.tr(),
        icon: HugeIcons.strokeRoundedAnalytics01,
        color: AppColors.accentDark,
        author: section.lfApproverName,
        timestamp: section.lfApprovedAt,
      ),
    );
  }

  if (section.status == EvidenceSectionStatus.validated &&
      section.unionApproverName != null) {
    entries.add(
      SacStatusHistoryEntry(
        label: 'evidence_folder.status.validated'.tr(),
        description: 'evidence_folder.status_history.validated_desc'.tr(),
        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
        color: AppColors.secondary,
        author: section.unionApproverName,
        timestamp: section.unionApprovedAt,
      ),
    );
  }

  return entries;
}

void showEvidenceStatusHistorySheet(
  BuildContext context, {
  required EvidenceSection section,
}) {
  showSacStatusHistorySheet(
    context,
    title: 'evidence_folder.status_history.title'.tr(),
    subtitle: section.name,
    entries: _evidenceStatusHistoryEntries(section),
    emptyTitle: 'evidence_folder.status_history.empty_title'.tr(),
    emptyBody: 'evidence_folder.status_history.empty_description'.tr(),
  );
}
