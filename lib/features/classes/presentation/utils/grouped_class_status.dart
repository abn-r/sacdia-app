import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/class_progress_summary.dart';
import '../../domain/entities/class_requirement.dart';

/// Backend counts mapped to the shared status grammar: "submitted" is a
/// requirement waiting on the local field, so it is the review group.
extension RequirementStatusCountsX on RequirementStatusCounts {
  StatusCounts toStatusCounts() => StatusCounts(
        validated: validated,
        review: submitted,
        rejected: rejected,
        pending: pending,
      );
}

/// Legend text of the status bar, pluralized per count.
SacStatusCountLabels groupedCountLabels(StatusCounts counts) =>
    SacStatusCountLabels(
      validated: 'classes.grouped.legend_validated'.plural(counts.validated),
      review: 'classes.grouped.legend_review'.plural(counts.review),
      rejected: 'classes.grouped.legend_rejected'.plural(counts.rejected),
      pending: 'classes.grouped.legend_pending'.plural(counts.pending),
    );

/// Group a requirement belongs to for a coach: rejected and observed both
/// mean "send it again", so they share the rejected style.
SacStatusKind requirementStatusKind(RequirementStatus status) {
  switch (status) {
    case RequirementStatus.pendiente:
      return SacStatusKind.pending;
    case RequirementStatus.enviado:
      return SacStatusKind.review;
    case RequirementStatus.validado:
      return SacStatusKind.validated;
    case RequirementStatus.rechazado:
    case RequirementStatus.observado:
      return SacStatusKind.rejected;
  }
}

/// Style (colors, icon and label) of a requirement status.
SacStatusStyle requirementStatusStyle(
  BuildContext context,
  RequirementStatus status,
) {
  final kind = requirementStatusKind(status);
  final HugeIconData? icon;
  final String label;
  switch (kind) {
    case SacStatusKind.pending:
      icon = HugeIcons.strokeRoundedFolder01;
      label = 'classes.grouped.state_pending'.tr();
    case SacStatusKind.rejected:
      icon = HugeIcons.strokeRoundedAlertCircle;
      label = 'classes.grouped.state_rejected'.tr();
    case SacStatusKind.review:
      icon = HugeIcons.strokeRoundedSent;
      label = 'classes.grouped.state_review'.tr();
    case SacStatusKind.validated:
      icon = HugeIcons.strokeRoundedCheckmarkCircle02;
      label = 'classes.grouped.state_validated'.tr();
  }
  return SacStatusStyle.of(context, kind, label: label, icon: icon);
}

/// Color of a progress percentage: done, on track, started, not started.
Color groupedProgressColor(BuildContext context, int percent) {
  final c = context.sac;
  if (percent >= 70) return c.success;
  if (percent >= 40) return SacAccent.of(context).color;
  if (percent > 0) return c.warning;
  return c.textTertiary;
}
