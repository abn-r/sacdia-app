import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';

/// Where an annual folder stands, in words.
String folderStatusLabel(SupervisionFolderStatus status) => switch (status) {
      SupervisionFolderStatus.open => 'supervision.folders.status_open',
      SupervisionFolderStatus.submitted =>
        'supervision.folders.status_submitted',
      SupervisionFolderStatus.underEvaluation =>
        'supervision.folders.status_under_evaluation',
      SupervisionFolderStatus.evaluated =>
        'supervision.folders.status_evaluated',
      SupervisionFolderStatus.closed => 'supervision.folders.status_closed',
      SupervisionFolderStatus.unknown => 'supervision.folders.status_unknown',
    }
        .tr();

/// Where a section of the folder stands, in words.
String sectionStatusLabel(SupervisionSectionStatus status) => switch (status) {
      SupervisionSectionStatus.pending => 'supervision.folders.section_pending',
      SupervisionSectionStatus.submitted =>
        'supervision.folders.section_submitted',
      SupervisionSectionStatus.preapprovedLf =>
        'supervision.folders.section_preapproved',
      SupervisionSectionStatus.validated =>
        'supervision.folders.section_validated',
      SupervisionSectionStatus.rejected =>
        'supervision.folders.section_rejected',
      SupervisionSectionStatus.unknown => 'supervision.folders.status_unknown',
    }
        .tr();

/// The status is always written next to the icon, never the icon alone.
HugeIconData sectionStatusIcon(SupervisionSectionStatus status) =>
    switch (status) {
      SupervisionSectionStatus.submitted => HugeIcons.strokeRoundedInbox,
      SupervisionSectionStatus.preapprovedLf => HugeIcons.strokeRoundedClock01,
      SupervisionSectionStatus.validated =>
        HugeIcons.strokeRoundedCheckmarkCircle02,
      SupervisionSectionStatus.rejected => HugeIcons.strokeRoundedCancel01,
      SupervisionSectionStatus.pending ||
      SupervisionSectionStatus.unknown =>
        HugeIcons.strokeRoundedFile01,
    };

/// Tint of the section icon: amber it is yours to evaluate, blue it waits for
/// the Union, green validated, red rejected, grey not sent yet.
SacTone sectionStatusTone(SupervisionSectionStatus status) => switch (status) {
      SupervisionSectionStatus.submitted => SacTone.warning,
      SupervisionSectionStatus.preapprovedLf => SacTone.info,
      SupervisionSectionStatus.validated => SacTone.success,
      SupervisionSectionStatus.rejected => SacTone.error,
      SupervisionSectionStatus.pending ||
      SupervisionSectionStatus.unknown =>
        SacTone.muted,
    };

/// Color and icon of the folder state panel: grey while the club still builds
/// it, blue while it is under review, green once evaluated or closed.
SacStatusStyle folderStatusStyle(
  BuildContext context,
  SupervisionFolderStatus status,
) {
  final label = folderStatusLabel(status);
  return switch (status) {
    SupervisionFolderStatus.open ||
    SupervisionFolderStatus.unknown =>
      SacStatusStyle.of(context, SacStatusKind.pending, label: label),
    SupervisionFolderStatus.submitted => SacStatusStyle.of(
        context,
        SacStatusKind.review,
        label: label,
        icon: HugeIcons.strokeRoundedFolder01,
      ),
    SupervisionFolderStatus.underEvaluation => SacStatusStyle.of(
        context,
        SacStatusKind.review,
        label: label,
        icon: HugeIcons.strokeRoundedFolderOpen,
      ),
    SupervisionFolderStatus.evaluated =>
      SacStatusStyle.of(context, SacStatusKind.validated, label: label),
    SupervisionFolderStatus.closed => SacStatusStyle.of(
        context,
        SacStatusKind.validated,
        label: label,
        icon: HugeIcons.strokeRoundedLock,
      ),
  };
}
