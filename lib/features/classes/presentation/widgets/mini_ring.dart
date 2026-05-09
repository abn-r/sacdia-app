import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Anillo de progreso compacto 36×36 para [ModuleRow].
///
/// Muestra porcentaje centrado en JetBrains Mono (si disponible) o monospace.
/// Track: `ink100`, arco: `coral500` (o `ink200` si pct == 0).
class MiniRing extends StatelessWidget {
  /// Progreso de 0.0 a 1.0.
  final double progress;

  /// Tamaño del widget. Por defecto 36.
  final double size;

  const MiniRing({
    super.key,
    required this.progress,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress.clamp(0.0, 1.0) * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MiniRingPainter(progress: progress.clamp(0.0, 1.0)),
        child: Center(
          child: Text(
            '$pct',
            style: TextStyle(
              fontSize: size * 0.25,
              fontWeight: FontWeight.w700,
              color: AppColors.ink800,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  final double progress;

  const _MiniRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const strokeWidth = 3.0;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.ink100
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc (only if > 0)
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = AppColors.coral500
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start from top
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
