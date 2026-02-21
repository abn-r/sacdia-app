import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// Animated progress ring — Apple Health / Fitness style.
///
/// On mount the arc fills from 0 to [progress] using a spring-like
/// [Curves.easeOutCubic] curve. Progress changes after mount animate
/// smoothly to the new value. Set [animate] to false for static rendering
/// or when the accessibility "reduce motion" setting is active.
///
/// The painter uses a sweep gradient (indigo → emerald) that rotates as the
/// arc grows, and rounded stroke caps for a polished look.
class SacProgressRing extends StatefulWidget {
  /// Progreso de 0.0 (0%) a 1.0 (100%)
  final double progress;

  /// Diámetro del ring en pixels lógicos
  final double size;

  /// Grosor del trazo
  final double strokeWidth;

  /// Widget opcional en el centro (por defecto muestra el porcentaje)
  final Widget? child;

  /// Color del progreso (inicio del gradiente). Default: AppColors.primary
  final Color? color;

  /// Color del track de fondo. Default: AppColors.lightBorderLight
  final Color? trackColor;

  /// Whether to animate the fill on mount and on value changes.
  final bool animate;

  /// Duration of the fill animation.
  final Duration animationDuration;

  const SacProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 8,
    this.child,
    this.color,
    this.trackColor,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  @override
  State<SacProgressRing> createState() => _SacProgressRingState();
}

class _SacProgressRingState extends State<SacProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    final clamped = widget.progress.clamp(0.0, 1.0);

    _progressAnimation = Tween<double>(begin: 0.0, end: clamped).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    final shouldAnimate = widget.animate;

    if (shouldAnimate) {
      // Small delay so the ring appears after the card entrance animation.
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(SacProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      final current = _progressAnimation.value;
      final clamped = widget.progress.clamp(0.0, 1.0);
      _progressAnimation = Tween<double>(
        begin: current,
        end: clamped,
      ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetProgress = widget.progress.clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, _) {
        final animatedProgress = _progressAnimation.value;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _ProgressRingPainter(
                  progress: animatedProgress,
                  strokeWidth: widget.strokeWidth,
                  progressColor: widget.color ?? AppColors.primary,
                  trackColor: widget.trackColor ?? AppColors.lightBorderLight,
                ),
              ),
              if (widget.child != null)
                widget.child!
              else
                Text(
                  '${(targetProgress * 100).round()}%',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track de fondo (círculo completo)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Arco de progreso con gradiente
    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress;

      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweepAngle,
        colors: [
          progressColor,
          AppColors.secondary,
        ],
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
