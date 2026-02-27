import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';

/// Widget de anillo de progreso circular
class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 a 100.0
  final double size;
  final double strokeWidth;

  const ProgressRing({
    Key? key,
    required this.progress,
    this.size = 60,
    this.strokeWidth = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Círculo de progreso
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress / 100,
              strokeWidth: strokeWidth,
              backgroundColor: context.sac.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(progress),
              ),
            ),
          ),
          // Texto de porcentaje
          Text(
            '${progress.toInt()}%',
            style: TextStyle(
              fontSize: size * 0.25,
              fontWeight: FontWeight.bold,
              color: _getProgressColor(progress),
            ),
          ),
        ],
      ),
    );
  }

  /// Obtiene el color según el progreso
  Color _getProgressColor(double progress) {
    if (progress >= 100) {
      return AppColors.success;
    } else if (progress >= 50) {
      return AppColors.info;
    } else if (progress >= 25) {
      return AppColors.warning;
    } else {
      return AppColors.error;
    }
  }
}
