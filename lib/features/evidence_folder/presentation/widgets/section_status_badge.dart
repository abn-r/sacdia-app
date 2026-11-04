import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_section.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Badge de color con ícono que indica el estado de la sección.
///
/// Cinco variantes visuales:
/// - pending        → amarillo / naranja
/// - submitted      → azul (dark-mode aware)
/// - preapprovedLf  → ámbar (pre-aprobado por campo local, pendiente de unión)
/// - validated      → verde
/// - rejected       → rojo
class SectionStatusBadge extends StatelessWidget {
  final EvidenceSectionStatus status;

  const SectionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    final bgColor = _bgColor(c);
    final borderColor = _borderColor(c);
    final textColor = _textColor(c);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: _icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Text(
            _label,
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String get _label {
    switch (status) {
      case EvidenceSectionStatus.pending:
        return 'evidence_folder.status.pending'.tr();
      case EvidenceSectionStatus.submitted:
        return 'evidence_folder.status.submitted'.tr();
      case EvidenceSectionStatus.preapprovedLf:
        return 'evidence_folder.status.preapproved'.tr();
      case EvidenceSectionStatus.validated:
        return 'evidence_folder.status.validated'.tr();
      case EvidenceSectionStatus.rejected:
        return 'evidence_folder.status.rejected'.tr();
    }
  }

  Color _bgColor(SacColors c) {
    switch (status) {
      case EvidenceSectionStatus.pending:
      case EvidenceSectionStatus.preapprovedLf:
        return c.warningContainer;
      case EvidenceSectionStatus.submitted:
        return c.infoContainer;
      case EvidenceSectionStatus.validated:
        return c.successContainer;
      case EvidenceSectionStatus.rejected:
        return c.errorContainer;
    }
  }

  Color _borderColor(SacColors c) {
    switch (status) {
      case EvidenceSectionStatus.pending:
        return c.warning.withValues(alpha: 0.4);
      case EvidenceSectionStatus.submitted:
        return c.info.withValues(alpha: 0.4);
      case EvidenceSectionStatus.preapprovedLf:
        return c.warning.withValues(alpha: 0.5);
      case EvidenceSectionStatus.validated:
        return c.success.withValues(alpha: 0.4);
      case EvidenceSectionStatus.rejected:
        return c.error.withValues(alpha: 0.4);
    }
  }

  Color _textColor(SacColors c) {
    switch (status) {
      case EvidenceSectionStatus.pending:
      case EvidenceSectionStatus.preapprovedLf:
        return c.onWarningContainer;
      case EvidenceSectionStatus.submitted:
        return c.onInfoContainer;
      case EvidenceSectionStatus.validated:
        return c.onSuccessContainer;
      case EvidenceSectionStatus.rejected:
        return c.onErrorContainer;
    }
  }

  HugeIconData get _icon {
    switch (status) {
      case EvidenceSectionStatus.pending:
        return HugeIcons.strokeRoundedClock01;
      case EvidenceSectionStatus.submitted:
        return HugeIcons.strokeRoundedSent;
      case EvidenceSectionStatus.preapprovedLf:
        return HugeIcons.strokeRoundedAnalytics01;
      case EvidenceSectionStatus.validated:
        return HugeIcons.strokeRoundedCheckmarkCircle01;
      case EvidenceSectionStatus.rejected:
        return HugeIcons.strokeRoundedCancel01;
    }
  }
}
