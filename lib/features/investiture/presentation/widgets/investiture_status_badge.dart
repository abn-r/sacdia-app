import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/investiture_status.dart';

/// Badge de color con ícono que indica el estado de investidura de un miembro.
///
/// Estados y colores:
/// - IN_PROGRESS        → gris (neutro)
/// - SUBMITTED          → amarillo/naranja
/// - APPROVED           → azul
/// - REJECTED           → rojo
/// - INVESTIDO          → verde
class InvestitureStatusBadge extends StatelessWidget {
  final InvestitureStatus status;

  const InvestitureStatusBadge({super.key, required this.status});

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
            status.label,
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

  Color _bgColor(bool isDark) {
    switch (status) {
      case InvestitureStatus.inProgress:
        return isDark
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFF1F5F9);
      case InvestitureStatus.submittedForValidation:
        return AppColors.accentLight;
      case InvestitureStatus.approved:
        return isDark
            ? AppColors.statusInfoBgDark
            : AppColors.statusInfoBgLight;
      case InvestitureStatus.rejected:
        return AppColors.errorLight;
      case InvestitureStatus.investido:
        return AppColors.secondaryLight;
    }
  }

  Color _borderColor(bool isDark) {
    switch (status) {
      case InvestitureStatus.inProgress:
        return isDark
            ? const Color(0xFF404040)
            : const Color(0xFFCBD5E1);
      case InvestitureStatus.submittedForValidation:
        return AppColors.accent.withValues(alpha: 0.4);
      case InvestitureStatus.approved:
        return AppColors.sacBlue.withValues(alpha: 0.4);
      case InvestitureStatus.rejected:
        return AppColors.error.withValues(alpha: 0.4);
      case InvestitureStatus.investido:
        return AppColors.secondary.withValues(alpha: 0.4);
    }
  }

  Color _textColor(bool isDark) {
    switch (status) {
      case InvestitureStatus.inProgress:
        return isDark
            ? const Color(0xFF94A3B8)
            : const Color(0xFF64748B);
      case InvestitureStatus.submittedForValidation:
        return AppColors.accentDark;
      case InvestitureStatus.approved:
        return isDark
            ? AppColors.statusInfoTextDark
            : AppColors.statusInfoText;
      case InvestitureStatus.rejected:
        return AppColors.errorDark;
      case InvestitureStatus.investido:
        return AppColors.secondaryDark;
    }
  }

  List<List<dynamic>> get _icon {
    switch (status) {
      case InvestitureStatus.inProgress:
        return HugeIcons.strokeRoundedClock01;
      case InvestitureStatus.submittedForValidation:
        return HugeIcons.strokeRoundedSent;
      case InvestitureStatus.approved:
        return HugeIcons.strokeRoundedCheckmarkCircle01;
      case InvestitureStatus.rejected:
        return HugeIcons.strokeRoundedCancel01;
      case InvestitureStatus.investido:
        return HugeIcons.strokeRoundedAward01;
    }
  }
}
