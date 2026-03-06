import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/class_requirement.dart';

/// Badge de color con icono que indica el estado de un requerimiento.
///
/// Tres variantes visuales:
/// - pendiente  -> amarillo / naranja
/// - enviado    -> azul
/// - validado   -> verde
class RequirementStatusBadge extends StatelessWidget {
  final RequirementStatus status;

  const RequirementStatusBadge({super.key, required this.status});

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
      case RequirementStatus.pendiente:
        return 'Pendiente';
      case RequirementStatus.enviado:
        return 'Enviado';
      case RequirementStatus.validado:
        return 'Validado';
    }
  }

  Color get _bgColor {
    switch (status) {
      case RequirementStatus.pendiente:
        return AppColors.accentLight;
      case RequirementStatus.enviado:
        return const Color(0xFFEFF6FF);
      case RequirementStatus.validado:
        return AppColors.secondaryLight;
    }
  }

  Color get _borderColor {
    switch (status) {
      case RequirementStatus.pendiente:
        return AppColors.accent.withValues(alpha: 0.4);
      case RequirementStatus.enviado:
        return AppColors.sacBlue.withValues(alpha: 0.4);
      case RequirementStatus.validado:
        return AppColors.secondary.withValues(alpha: 0.4);
    }
  }

  Color get _textColor {
    switch (status) {
      case RequirementStatus.pendiente:
        return AppColors.accentDark;
      case RequirementStatus.enviado:
        return const Color(0xFF1D4ED8);
      case RequirementStatus.validado:
        return AppColors.secondaryDark;
    }
  }

  List<List<dynamic>> get _icon {
    switch (status) {
      case RequirementStatus.pendiente:
        return HugeIcons.strokeRoundedClock01;
      case RequirementStatus.enviado:
        return HugeIcons.strokeRoundedSent;
      case RequirementStatus.validado:
        return HugeIcons.strokeRoundedCheckmarkCircle01;
    }
  }
}
