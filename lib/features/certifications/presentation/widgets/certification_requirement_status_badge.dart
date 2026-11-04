import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

import '../../domain/entities/certification_requirement.dart';

/// Badge de estado para un requisito (sección) de certificación.
///
/// Vocabulario propio de certificaciones (DRAFT/SUBMITTED/CHANGES_REQUESTED/
/// APPROVED) — deliberadamente distinto del de clases progresivas
/// (pendiente/enviado/validado/rechazado), ver decisión en el plan de
/// ejecución (Fase 5, punto 5 de "Decisiones ya tomadas").
///
/// Se renderiza con [SacBadge] (tintas de estado del design system).
class CertificationRequirementStatusBadge extends StatelessWidget {
  final CertificationRequirementStatus status;

  const CertificationRequirementStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return SacBadge(label: _label, icon: _icon, variant: _variant);
  }

  String get _label {
    switch (status) {
      case CertificationRequirementStatus.draft:
        return 'certifications.requirement_status.draft'.tr();
      case CertificationRequirementStatus.submitted:
        return 'certifications.requirement_status.submitted'.tr();
      case CertificationRequirementStatus.changesRequested:
        return 'certifications.requirement_status.changes_requested'.tr();
      case CertificationRequirementStatus.approved:
        return 'certifications.requirement_status.approved'.tr();
    }
  }

  SacBadgeVariant get _variant {
    switch (status) {
      case CertificationRequirementStatus.draft:
      case CertificationRequirementStatus.changesRequested:
        return SacBadgeVariant.accent;
      case CertificationRequirementStatus.submitted:
        return SacBadgeVariant.info;
      case CertificationRequirementStatus.approved:
        return SacBadgeVariant.secondary;
    }
  }

  HugeIconData get _icon {
    switch (status) {
      case CertificationRequirementStatus.draft:
        return HugeIcons.strokeRoundedEdit02;
      case CertificationRequirementStatus.submitted:
        return HugeIcons.strokeRoundedSent;
      case CertificationRequirementStatus.changesRequested:
        return HugeIcons.strokeRoundedInformationCircle;
      case CertificationRequirementStatus.approved:
        return HugeIcons.strokeRoundedCheckmarkCircle01;
    }
  }
}
