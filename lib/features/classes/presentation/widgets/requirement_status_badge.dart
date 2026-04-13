import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/class_requirement.dart';

/// Badge de color con icono que indica el estado de un requerimiento.
///
/// Cuatro variantes visuales:
/// - pendiente  -> amarillo / naranja
/// - enviado    -> azul (dark-mode aware)
/// - validado   -> verde
/// - rechazado  -> rojo
class RequirementStatusBadge extends StatelessWidget {
  final RequirementStatus status;

  const RequirementStatusBadge({super.key, required this.status});

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
      case RequirementStatus.pendiente:
        return 'Pendiente';
      case RequirementStatus.enviado:
        return 'Enviado';
      case RequirementStatus.validado:
        return 'Validado';
      case RequirementStatus.rechazado:
        return 'Rechazado';
    }
  }

  Color _bgColor(bool isDark) {
    switch (status) {
      case RequirementStatus.pendiente:
        return AppColors.accentLight;
      case RequirementStatus.enviado:
        return isDark ? AppColors.statusInfoBgDark : AppColors.statusInfoBgLight;
      case RequirementStatus.validado:
        return AppColors.secondaryLight;
      case RequirementStatus.rechazado:
        return AppColors.errorLight;
    }
  }

  Color _borderColor(bool isDark) {
    switch (status) {
      case RequirementStatus.pendiente:
        return AppColors.accent.withValues(alpha: 0.4);
      case RequirementStatus.enviado:
        return AppColors.sacBlue.withValues(alpha: 0.4);
      case RequirementStatus.validado:
        return AppColors.secondary.withValues(alpha: 0.4);
      case RequirementStatus.rechazado:
        return AppColors.error.withValues(alpha: 0.4);
    }
  }

  Color _textColor(bool isDark) {
    switch (status) {
      case RequirementStatus.pendiente:
        return AppColors.accentDark;
      case RequirementStatus.enviado:
        return isDark ? AppColors.statusInfoTextDark : AppColors.statusInfoText;
      case RequirementStatus.validado:
        return AppColors.secondaryDark;
      case RequirementStatus.rechazado:
        return AppColors.errorDark;
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
      case RequirementStatus.rechazado:
        return HugeIcons.strokeRoundedCancel01;
    }
  }
}
