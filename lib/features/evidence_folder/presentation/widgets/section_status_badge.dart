import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/evidence_section.dart';

/// Badge de color con ícono que indica el estado de la sección.
///
/// Tres variantes visuales:
/// - pendiente  → amarillo / naranja
/// - enviado    → azul (dark-mode aware)
/// - validado   → verde
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
    }
  }
}
