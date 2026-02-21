import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// Confetti / particle celebration overlay — Duolingo streak-complete style.
///
/// Shows a burst of coloured particles that fall from the top of the screen,
/// then auto-dismisses after [duration]. No external packages required —
/// built entirely with [CustomPainter] and [AnimationController].
///
/// Usage — show programmatically:
/// ```dart
/// CelebrationOverlay.show(context);
/// ```
///
/// Usage — embed as a stack child with manual control:
/// ```dart
/// CelebrationOverlay(
///   onComplete: () => setState(() => _showCelebration = false),
/// )
/// ```

// ──────────────────────────────────────────────────────────────────────────
// Public API
// ──────────────────────────────────────────────────────────────────────────

class CelebrationOverlay extends StatefulWidget {
  /// Called when the animation finishes and the overlay should be removed.
  final VoidCallback? onComplete;

  /// How long the full particle animation runs.
  final Duration duration;

  const CelebrationOverlay({
    super.key,
    this.onComplete,
    this.duration = const Duration(milliseconds: 2200),
  });

  /// Inserts the overlay into the [Overlay] of the nearest [Navigator].
  ///
  /// The overlay removes itself automatically when the animation finishes.
  static void show(
    BuildContext context, {
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => CelebrationOverlay(
        duration: duration,
        onComplete: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final math.Random _rng = math.Random();

  // SACDIA Scout Vibrante palette + festive extras
  static const List<Color> _palette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    Color(0xFFF43F5E), // rose
    Color(0xFF8B5CF6), // violet
    Color(0xFF06B6D4), // cyan
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete?.call();
        }
      });

    // Generate particles — deferred until first layout so we have screen size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      _particles = _generateParticles(size);
      _controller.forward();
    });

    _particles = [];
  }

  List<_Particle> _generateParticles(Size screenSize) {
    return List.generate(72, (i) {
      return _Particle(
        color: _palette[_rng.nextInt(_palette.length)],
        // Spawn across the full width, mostly near the top.
        xStart: _rng.nextDouble() * screenSize.width,
        yStart: -20 - _rng.nextDouble() * 60,
        // Horizontal drift — some go left, some right.
        xVelocity: (_rng.nextDouble() - 0.5) * screenSize.width * 0.6,
        // Vertical fall speed.
        yVelocity: screenSize.height * (0.55 + _rng.nextDouble() * 0.5),
        // Each particle picks its own start time so they don't all burst at once.
        delay: _rng.nextDouble() * 0.45,
        size: 6 + _rng.nextDouble() * 8,
        rotation: _rng.nextDouble() * math.pi * 2,
        rotationSpeed: (_rng.nextDouble() - 0.5) * math.pi * 6,
        isCircle: _rng.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_particles.isEmpty) return const SizedBox.expand();
          return CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              progress: _controller.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Particle data model
// ──────────────────────────────────────────────────────────────────────────

class _Particle {
  final Color color;
  final double xStart;
  final double yStart;
  final double xVelocity;
  final double yVelocity;
  final double delay; // 0..1 fraction of total duration
  final double size;
  final double rotation;
  final double rotationSpeed;
  final bool isCircle;

  const _Particle({
    required this.color,
    required this.xStart,
    required this.yStart,
    required this.xVelocity,
    required this.yVelocity,
    required this.delay,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.isCircle,
  });
}

// ──────────────────────────────────────────────────────────────────────────
// Painter
// ──────────────────────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1

  const _ParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Each particle has its own local timeline after its delay.
      final localT = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;

      // Physics: constant horizontal + gravity-accelerated vertical.
      final x = p.xStart + p.xVelocity * localT;
      // Add a gentle gravity curve so pieces arc down naturally.
      final y = p.yStart + p.yVelocity * localT * localT;

      // Fade out in the last 35% of the particle's lifetime.
      final alpha = localT > 0.65
          ? (1.0 - (localT - 0.65) / 0.35).clamp(0.0, 1.0)
          : 1.0;

      paint.color = p.color.withValues(alpha: alpha);

      final currentRotation = p.rotation + p.rotationSpeed * localT;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(currentRotation);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        // Rectangle confetti piece.
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
