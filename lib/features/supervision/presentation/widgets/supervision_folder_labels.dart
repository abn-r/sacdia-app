import 'package:easy_localization/easy_localization.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
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
      SupervisionSectionStatus.preapprovedLf =>
        HugeIcons.strokeRoundedTaskDone01,
      SupervisionSectionStatus.validated =>
        HugeIcons.strokeRoundedCheckmarkCircle02,
      SupervisionSectionStatus.rejected => HugeIcons.strokeRoundedCancel01,
      SupervisionSectionStatus.pending ||
      SupervisionSectionStatus.unknown =>
        HugeIcons.strokeRoundedFile01,
    };
