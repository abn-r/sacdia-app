import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/evidence_section.dart';

/// Badge de color con ícono que indica el estado de la sección.
///
/// Tres variantes visuales:
/// - pendiente  → amarillo / naranja
/// - enviado    → azul
/// - validado   → verde
class SectionStatusBadge extends StatelessWidget {
  final EvidenceSectionStatus status;

  const SectionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: _icon, size: 13, color: _textColor),
          const SizedBox(width: 5),
          Text(
            _label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textColor,
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

  Color get _bgColor {
    switch (status) {
      case EvidenceSectionStatus.pendiente:
        return AppColors.accentLight;
      case EvidenceSectionStatus.enviado:
        return const Color(0xFFEFF6FF);
      case EvidenceSectionStatus.validado:
        return AppColors.secondaryLight;
    }
  }

  Color get _borderColor {
    switch (status) {
      case EvidenceSectionStatus.pendiente:
        return AppColors.accent.withValues(alpha: 0.4);
      case EvidenceSectionStatus.enviado:
        return AppColors.sacBlue.withValues(alpha: 0.4);
      case EvidenceSectionStatus.validado:
        return AppColors.secondary.withValues(alpha: 0.4);
    }
  }

  Color get _textColor {
    switch (status) {
      case EvidenceSectionStatus.pendiente:
        return AppColors.accentDark;
      case EvidenceSectionStatus.enviado:
        return const Color(0xFF1D4ED8);
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
