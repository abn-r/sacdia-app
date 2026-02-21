import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

/// Botón de asistencia - Estilo "Scout Vibrante"
///
/// Estado confirmado: SacCard emerald con check.
/// Estado pendiente: SacButton.primary indigo.
class AttendanceButton extends StatelessWidget {
  final bool isAttending;
  final bool isLoading;
  final VoidCallback onPressed;

  const AttendanceButton({
    super.key,
    required this.isAttending,
    this.isLoading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isAttending) {
      return SacCard(
        backgroundColor: AppColors.secondaryLight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                size: 20, color: AppColors.secondaryDark),
            const SizedBox(width: 8),
            Text(
              'Asistencia confirmada',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryDark,
              ),
            ),
          ],
        ),
      );
    }

    return SacButton.primary(
      text: 'Confirmar asistencia',
      icon: HugeIcons.strokeRoundedUserCheck01,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}
