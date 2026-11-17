import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/evidence_section.dart';

/// What a section status means for the club, in three groups.
///
/// Color follows the group (what the club has to do); the icon tells the
/// exact state apart inside a group, so meaning never rests on color alone.
enum EvidenceStatusGroup {
  /// Rejected or not sent yet: the club has work to do.
  attention,

  /// Sent or approved by the local field: waiting for someone else.
  review,

  /// Validated: done.
  validated,
}

extension EvidenceSectionStatusGroupX on EvidenceSectionStatus {
  EvidenceStatusGroup get group {
    switch (this) {
      case EvidenceSectionStatus.pending:
      case EvidenceSectionStatus.rejected:
        return EvidenceStatusGroup.attention;
      case EvidenceSectionStatus.submitted:
      case EvidenceSectionStatus.preapprovedLf:
        return EvidenceStatusGroup.review;
      case EvidenceSectionStatus.validated:
        return EvidenceStatusGroup.validated;
    }
  }
}

/// Maps a section status onto the shared [SacStatusStyle]: same colors per
/// group, with the icon and label that tell the exact state apart.
abstract final class EvidenceStatusStyle {
  static SacStatusStyle of(BuildContext context, EvidenceSectionStatus status) {
    switch (status) {
      case EvidenceSectionStatus.pending:
        return SacStatusStyle.of(
          context,
          SacStatusKind.pending,
          icon: HugeIcons.strokeRoundedFolder01,
          label: 'evidence_folder.state.pending'.tr(),
        );
      case EvidenceSectionStatus.rejected:
        return SacStatusStyle.of(
          context,
          SacStatusKind.rejected,
          icon: HugeIcons.strokeRoundedAlertCircle,
          label: 'evidence_folder.state.rejected'.tr(),
        );
      case EvidenceSectionStatus.submitted:
        return SacStatusStyle.of(
          context,
          SacStatusKind.review,
          icon: HugeIcons.strokeRoundedSent,
          label: 'evidence_folder.state.submitted'.tr(),
        );
      case EvidenceSectionStatus.preapprovedLf:
        return SacStatusStyle.of(
          context,
          SacStatusKind.review,
          icon: HugeIcons.strokeRoundedCheckmarkBadge01,
          label: 'evidence_folder.state.preapproved'.tr(),
        );
      case EvidenceSectionStatus.validated:
        return SacStatusStyle.of(
          context,
          SacStatusKind.validated,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          label: 'evidence_folder.state.validated'.tr(),
        );
    }
  }
}
