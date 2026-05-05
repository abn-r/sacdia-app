import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';

/// Widget de anillo de progreso circular — versión original (legacy).
///
/// Para el HeroCard de avances usa [HeroDonut] (56×56, stroke 6px, coral500).
class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 a 100.0
  final double size;
  final double strokeWidth;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 60,
    this.strokeWidth = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
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

  Color _getProgressColor(double progress) {
    if (progress >= 100) return AppColors.success;
    if (progress >= 50) return AppColors.info;
    if (progress >= 25) return AppColors.warning;
    return AppColors.error;
  }
}

/// Donut de 56×56 para el HeroCard de avances.
///
/// Track: `ink100`, arco: `coral500`, stroke 6px, linecap round, arranca arriba.
class HeroDonut extends StatelessWidget {
  /// Progreso de 0.0 a 1.0.
  final double progress;

  const HeroDonut({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(
        painter: _HeroDonutPainter(progress: progress.clamp(0.0, 1.0)),
      ),
    );
  }
}

class _HeroDonutPainter extends CustomPainter {
  final double progress;

  const _HeroDonutPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    const strokeWidth = 6.0;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.ink100
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = AppColors.coral500
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start from top (-90deg)
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeroDonutPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
