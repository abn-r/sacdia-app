import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/evidence_section.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = _bgColor(isDark);
    final borderColor = _borderColor(isDark);
    final textColor = _textColor(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
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
              fontSize: 12,
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
        return 'Pendiente';
      case EvidenceSectionStatus.submitted:
        return 'Enviado';
      case EvidenceSectionStatus.preapprovedLf:
        return 'Preaprobado';
      case EvidenceSectionStatus.validated:
        return 'Validado';
      case EvidenceSectionStatus.rejected:
        return 'Rechazado';
    }
  }

  Color _bgColor(bool isDark) {
    switch (status) {
      case EvidenceSectionStatus.pending:
        return AppColors.accentLight;
      case EvidenceSectionStatus.submitted:
        return isDark
            ? AppColors.statusInfoBgDark
            : AppColors.statusInfoBgLight;
      case EvidenceSectionStatus.preapprovedLf:
        return isDark ? AppColors.darkSurfaceVariant : AppColors.accentLight;
      case EvidenceSectionStatus.validated:
        return AppColors.secondaryLight;
      case EvidenceSectionStatus.rejected:
        return AppColors.errorLight;
    }
  }

  Color _borderColor(bool isDark) {
    switch (status) {
      case EvidenceSectionStatus.pending:
        return AppColors.accent.withValues(alpha: 0.4);
      case EvidenceSectionStatus.submitted:
        return AppColors.sacBlue.withValues(alpha: 0.4);
      case EvidenceSectionStatus.preapprovedLf:
        return AppColors.accent.withValues(alpha: 0.5);
      case EvidenceSectionStatus.validated:
        return AppColors.secondary.withValues(alpha: 0.4);
      case EvidenceSectionStatus.rejected:
        return AppColors.error.withValues(alpha: 0.4);
    }
  }

  Color _textColor(bool isDark) {
    switch (status) {
      case EvidenceSectionStatus.pending:
        return AppColors.accentDark;
      case EvidenceSectionStatus.submitted:
        return isDark ? AppColors.statusInfoTextDark : AppColors.statusInfoText;
      case EvidenceSectionStatus.preapprovedLf:
        return AppColors.accentDark;
      case EvidenceSectionStatus.validated:
        return AppColors.secondaryDark;
      case EvidenceSectionStatus.rejected:
        return AppColors.errorDark;
    }
  }

  List<List<dynamic>> get _icon {
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
