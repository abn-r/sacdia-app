import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';

/// Donut de 56×56 para el HeroCard de avances.
///
/// Track: `ink100`, arco configurable, stroke 6px, linecap round, arranca arriba.
///
/// El arco hace tween desde su valor en pantalla hacia el nuevo target
/// (interruptible via [TweenAnimationBuilder]); con Reduced Motion salta
/// directo al valor final.
class HeroDonut extends StatelessWidget {
  /// Progreso de 0.0 a 1.0.
  final double progress;
  final Color color;

  const HeroDonut({
    super.key,
    required this.progress,
    this.color = AppColors.coral500,
  });

  @override
  Widget build(BuildContext context) {
    final target = progress.clamp(0.0, 1.0);
    final reduce = SacMotion.reduceMotionOf(context);

    return RepaintBoundary(
      child: SizedBox(
        width: 56,
        height: 56,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target),
          duration: reduce ? Duration.zero : SacMotion.modal,
          curve: SacMotion.easeOut,
          builder: (context, animatedProgress, _) => CustomPaint(
            painter: _HeroDonutPainter(
              progress: animatedProgress,
              color: color,
              trackColor: context.sac.ink100,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroDonutPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _HeroDonutPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    const strokeWidth = 6.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
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
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}
