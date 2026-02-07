import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget de botón de asistencia
class AttendanceButton extends StatelessWidget {
  final bool isAttending;
  final bool isLoading;
  final VoidCallback onPressed;

  const AttendanceButton({
    Key? key,
    required this.isAttending,
    this.isLoading = false,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(isAttending ? Icons.check_circle : Icons.add_circle),
        label: Text(isAttending ? 'Asistencia registrada' : 'Registrar asistencia'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isAttending ? AppColors.success : AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          disabledBackgroundColor:
              isAttending ? AppColors.success.withOpacity(0.6) : null,
        ),
      ),
    );
  }
}
