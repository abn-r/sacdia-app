import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_status_history_sheet.dart';

import '../../domain/entities/class_requirement.dart';

/// Historial de transiciones de un requerimiento de clase.
///
/// Los datos son snapshots de trazabilidad en [ClassRequirement], no un
/// array de historial del backend. Llamar con [showRequirementStatusHistorySheet].
class RequirementStatusHistorySheet extends StatelessWidget {
  const RequirementStatusHistorySheet({
    super.key,
    required this.requirement,
  });

  final ClassRequirement requirement;

  @override
  Widget build(BuildContext context) {
    return SacStatusHistorySheet(
      title: 'classes.status_history.title'.tr(),
      subtitle: requirement.name,
      entries: _requirementStatusHistoryEntries(requirement),
      emptyTitle: 'classes.status_history.empty_title'.tr(),
      emptyBody: 'classes.status_history.empty_body'.tr(),
    );
  }
}

List<SacStatusHistoryEntry> _requirementStatusHistoryEntries(
  ClassRequirement requirement,
) {
  final entries = <SacStatusHistoryEntry>[
    SacStatusHistoryEntry(
      label: 'classes.status.pending'.tr(),
      description: 'classes.status_history.created_desc'.tr(),
      icon: HugeIcons.strokeRoundedClock01,
      color: AppColors.accent,
    ),
  ];

  if (requirement.status == RequirementStatus.enviado ||
      requirement.status == RequirementStatus.validado ||
      requirement.status == RequirementStatus.rechazado) {
    entries.add(
      SacStatusHistoryEntry(
        label: 'classes.status.sent'.tr(),
        description: 'classes.status_history.sent_desc'.tr(),
        icon: HugeIcons.strokeRoundedSent,
        color: AppColors.info,
        author: requirement.submittedByName,
        timestamp: requirement.submittedAt,
      ),
    );
  }

  if (requirement.status == RequirementStatus.validado) {
    entries.add(
      SacStatusHistoryEntry(
        label: 'classes.status.validated'.tr(),
        description: 'classes.status_history.validated_desc'.tr(),
        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
        color: AppColors.secondary,
        author: requirement.validatedByName,
        timestamp: requirement.validatedAt,
      ),
    );
  }

  if (requirement.status == RequirementStatus.rechazado) {
    entries.add(
      SacStatusHistoryEntry(
        label: 'classes.status.rejected'.tr(),
        description: 'classes.status_history.rejected_desc'.tr(),
        icon: HugeIcons.strokeRoundedCancel01,
        color: AppColors.error,
        author: requirement.validatedByName,
        timestamp: requirement.validatedAt,
      ),
    );
  }

  return entries;
}

void showRequirementStatusHistorySheet(
  BuildContext context, {
  required ClassRequirement requirement,
}) {
  showSacStatusHistorySheet(
    context,
    title: 'classes.status_history.title'.tr(),
    subtitle: requirement.name,
    entries: _requirementStatusHistoryEntries(requirement),
    emptyTitle: 'classes.status_history.empty_title'.tr(),
    emptyBody: 'classes.status_history.empty_body'.tr(),
  );
}
