import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../../../core/theme/sac_colors.dart';
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

/// Colors, icon and label for one section status. One source for rows,
/// the summary bar and the detail panel.
class EvidenceStatusStyle {
  const EvidenceStatusStyle({
    required this.container,
    required this.onContainer,
    required this.solid,
    required this.icon,
    required this.label,
  });

  /// Tinted background (row icon, status panel).
  final Color container;

  /// Text and icons on [container], and status text on surface.
  final Color onContainer;

  /// Solid fill for the progress bar and timeline dots.
  final Color solid;

  final HugeIconData icon;
  final String label;

  factory EvidenceStatusStyle.of(
    BuildContext context,
    EvidenceSectionStatus status,
  ) {
    final c = context.sac;
    switch (status) {
      case EvidenceSectionStatus.pending:
        return EvidenceStatusStyle(
          container: c.surfaceVariant,
          onContainer: c.textSecondary,
          solid: c.textTertiary.withValues(alpha: 0.45),
          icon: HugeIcons.strokeRoundedFolder01,
          label: 'evidence_folder.state.pending'.tr(),
        );
      case EvidenceSectionStatus.rejected:
        return EvidenceStatusStyle(
          container: c.errorContainer,
          onContainer: c.onErrorContainer,
          solid: c.error,
          icon: HugeIcons.strokeRoundedAlertCircle,
          label: 'evidence_folder.state.rejected'.tr(),
        );
      case EvidenceSectionStatus.submitted:
        return EvidenceStatusStyle(
          container: c.infoContainer,
          onContainer: c.onInfoContainer,
          solid: c.info,
          icon: HugeIcons.strokeRoundedSent,
          label: 'evidence_folder.state.submitted'.tr(),
        );
      case EvidenceSectionStatus.preapprovedLf:
        return EvidenceStatusStyle(
          container: c.infoContainer,
          onContainer: c.onInfoContainer,
          solid: c.info,
          icon: HugeIcons.strokeRoundedCheckmarkBadge01,
          label: 'evidence_folder.state.preapproved'.tr(),
        );
      case EvidenceSectionStatus.validated:
        return EvidenceStatusStyle(
          container: c.successContainer,
          onContainer: c.onSuccessContainer,
          solid: c.success,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          label: 'evidence_folder.state.validated'.tr(),
        );
    }
  }
}
