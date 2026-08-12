import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/certification_requirement.dart';

/// Badge de estado para un requisito (sección) de certificación.
///
/// Vocabulario propio de certificaciones (DRAFT/SUBMITTED/CHANGES_REQUESTED/
/// APPROVED) — deliberadamente distinto del de clases progresivas
/// (pendiente/enviado/validado/rechazado), ver decisión en el plan de
/// ejecución (Fase 5, punto 5 de "Decisiones ya tomadas").
class CertificationRequirementStatusBadge extends StatelessWidget {
  final CertificationRequirementStatus status;

  const CertificationRequirementStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColor(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(isDark), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: _icon, size: 13, color: _textColor(isDark)),
          const SizedBox(width: 5),
          Text(
            _label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textColor(isDark),
            ),
          ),
        ],
      ),
    );
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

  Color _bgColor(bool isDark) {
    switch (status) {
      case CertificationRequirementStatus.draft:
        return AppColors.accentLight;
      case CertificationRequirementStatus.submitted:
        return isDark
            ? AppColors.statusInfoBgDark
            : AppColors.statusInfoBgLight;
      case CertificationRequirementStatus.changesRequested:
        return AppColors.observedBg;
      case CertificationRequirementStatus.approved:
        return AppColors.secondaryLight;
    }
  }

  Color _borderColor(bool isDark) {
    switch (status) {
      case CertificationRequirementStatus.draft:
        return AppColors.accent.withValues(alpha: 0.4);
      case CertificationRequirementStatus.submitted:
        return AppColors.info.withValues(alpha: 0.4);
      case CertificationRequirementStatus.changesRequested:
        return AppColors.observedColor.withValues(alpha: 0.4);
      case CertificationRequirementStatus.approved:
        return AppColors.secondary.withValues(alpha: 0.4);
    }
  }

  Color _textColor(bool isDark) {
    switch (status) {
      case CertificationRequirementStatus.draft:
        return AppColors.accentDark;
      case CertificationRequirementStatus.submitted:
        return isDark ? AppColors.statusInfoTextDark : AppColors.statusInfoText;
      case CertificationRequirementStatus.changesRequested:
        return AppColors.observedDark;
      case CertificationRequirementStatus.approved:
        return AppColors.secondaryDark;
    }
  }

  List<List<dynamic>> get _icon {
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
