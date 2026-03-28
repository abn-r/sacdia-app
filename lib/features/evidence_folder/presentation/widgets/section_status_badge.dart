import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/evidence_section.dart';

/// Badge de color con ícono que indica el estado de la sección.
///
/// Seis variantes visuales:
/// - pendiente        → amarillo / naranja
/// - enviado          → azul (dark-mode aware)
/// - validado         → verde
/// - rechazado        → rojo
/// - underEvaluation  → ámbar (en proceso de evaluación)
/// - evaluated        → verde oscuro (evaluación completa con puntos)
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
      case EvidenceSectionStatus.pendiente:
        return 'Pendiente';
      case EvidenceSectionStatus.enviado:
        return 'Enviado';
      case EvidenceSectionStatus.validado:
        return 'Validado';
      case EvidenceSectionStatus.rechazado:
        return 'Rechazado';
      case EvidenceSectionStatus.underEvaluation:
        return 'En evaluación';
      case EvidenceSectionStatus.evaluated:
        return 'Evaluado';
    }
  }

  Color _bgColor(bool isDark) {
    switch (status) {
      case EvidenceSectionStatus.pendiente:
        return AppColors.accentLight;
      case EvidenceSectionStatus.enviado:
        return isDark ? AppColors.statusInfoBgDark : AppColors.statusInfoBgLight;
      case EvidenceSectionStatus.validado:
        return AppColors.secondaryLight;
      case EvidenceSectionStatus.rechazado:
        return AppColors.errorLight;
      case EvidenceSectionStatus.underEvaluation:
        // Ámbar suave para indicar proceso activo
        return isDark
            ? const Color(0xFF2D2010)
            : const Color(0xFFFFF8E1);
      case EvidenceSectionStatus.evaluated:
        return AppColors.secondaryLight;
    }
  }

  Color _borderColor(bool isDark) {
    switch (status) {
      case EvidenceSectionStatus.pendiente:
        return AppColors.accent.withValues(alpha: 0.4);
      case EvidenceSectionStatus.enviado:
        return AppColors.sacBlue.withValues(alpha: 0.4);
      case EvidenceSectionStatus.validado:
        return AppColors.secondary.withValues(alpha: 0.4);
      case EvidenceSectionStatus.rechazado:
        return AppColors.error.withValues(alpha: 0.4);
      case EvidenceSectionStatus.underEvaluation:
        return const Color(0xFFF59E0B).withValues(alpha: 0.5);
      case EvidenceSectionStatus.evaluated:
        return AppColors.secondaryDark.withValues(alpha: 0.4);
    }
  }

  Color _textColor(bool isDark) {
    switch (status) {
      case EvidenceSectionStatus.pendiente:
        return AppColors.accentDark;
      case EvidenceSectionStatus.enviado:
        return isDark ? AppColors.statusInfoTextDark : AppColors.statusInfoText;
      case EvidenceSectionStatus.validado:
        return AppColors.secondaryDark;
      case EvidenceSectionStatus.rechazado:
        return AppColors.errorDark;
      case EvidenceSectionStatus.underEvaluation:
        return isDark
            ? const Color(0xFFFBBF24)
            : const Color(0xFF92400E);
      case EvidenceSectionStatus.evaluated:
        return AppColors.secondaryDark;
    }
  }

  List<List<dynamic>> get _icon {
    switch (status) {
      case EvidenceSectionStatus.pendiente:
        return HugeIcons.strokeRoundedClock01;
      case EvidenceSectionStatus.enviado:
        return HugeIcons.strokeRoundedSent;
      case EvidenceSectionStatus.validado:
        return HugeIcons.strokeRoundedCheckmarkCircle01;
      case EvidenceSectionStatus.rechazado:
        return HugeIcons.strokeRoundedCancel01;
      case EvidenceSectionStatus.underEvaluation:
        return HugeIcons.strokeRoundedAnalytics01;
      case EvidenceSectionStatus.evaluated:
        return HugeIcons.strokeRoundedStar;
    }
  }
}
