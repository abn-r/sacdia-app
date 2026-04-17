import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

import '../../domain/entities/achievement.dart';
import '../../domain/entities/user_achievement.dart';
import 'achievement_badge.dart';

/// Overlay de animación de desbloqueo de logro.
///
/// Muestra un overlay semi-transparente con:
/// - Badge escalando desde 0 → 1.2 → 1.0 con curva bounceOut
/// - Burst de partículas del color del tier
/// - Texto "¡Logro desbloqueado!" + nombre del logro
/// - Auto-dismiss en 3 segundos o tap para cerrar
///
/// Uso:
/// ```dart
/// AchievementUnlockAnimation.show(context, achievement);
/// ```
class AchievementUnlockAnimation {
  AchievementUnlockAnimation._();

  /// Muestra el overlay de desbloqueo de logro.
  static void show(BuildContext context, Achievement achievement) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _UnlockOverlay(
        achievement: achievement,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _UnlockOverlay extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onDismiss;

  const _UnlockOverlay({
    required this.achievement,
    required this.onDismiss,
  });

  @override
  State<_UnlockOverlay> createState() => _UnlockOverlayState();
}

class _UnlockOverlayState extends State<_UnlockOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _badgeController;
  late final AnimationController _textController;
  late final AnimationController _particlesController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _textFadeAnimation;
  late final Animation<double> _particleAnimation;

  @override
  void initState() {
    super.initState();

    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Badge: 0 → 1.2 → 1.0 (bounceOut style)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_badgeController);

    _textFadeAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    _particleAnimation = CurvedAnimation(
      parent: _particlesController,
      curve: Curves.easeOut,
    );

    // Start sequence
    _badgeController.forward().then((_) {
      if (mounted) _textController.forward();
      if (mounted) _particlesController.forward();
    });

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _badgeController.dispose();
    _textController.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = achievementTierColor(widget.achievement.tier);

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Material(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Particle burst + badge
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Particle burst
                    AnimatedBuilder(
                      animation: _particleAnimation,
                      builder: (context, _) => CustomPaint(
                        size: const Size(200, 200),
                        painter: _ParticlePainter(
                          progress: _particleAnimation.value,
                          color: tierColor,
                        ),
                      ),
                    ),

                    // Glow ring
                    AnimatedBuilder(
                      animation: _badgeController,
                      builder: (context, _) => Container(
                        width: 130 * _scaleAnimation.value,
                        height: 130 * _scaleAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: tierColor.withValues(alpha: 0.5),
                              blurRadius: 40,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Badge
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                      child: AchievementBadge(
                        badgeImageUrl: widget.achievement.badgeImageUrl,
                        tier: widget.achievement.tier,
                        visualState: AchievementVisualState.unlocked,
                        isSecret: false,
                        size: 96,
                        progress: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Text content
              FadeTransition(
                opacity: _textFadeAnimation,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: tierColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedAward01,
                            size: 16,
                            color: tierColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '¡Logro desbloqueado!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tierColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        widget.achievement.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt, size: 14, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.achievement.points} puntos',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Toca para cerrar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painter para partículas radiales del burst de desbloqueo
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  static const int _particleCount = 12;

  _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: (1.0 - progress) * 0.9)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < _particleCount; i++) {
      final angle = (i / _particleCount) * 2 * math.pi;
      final radius = maxRadius * progress;
      final particleSize = 6.0 * (1.0 - progress);

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      canvas.drawCircle(Offset(x, y), particleSize.clamp(1.0, 6.0), paint);
    }

    // Secondary ring of smaller particles at offset angle
    final smallPaint = Paint()
      ..color = Colors.white.withValues(alpha: (1.0 - progress) * 0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < _particleCount; i++) {
      final angle = (i / _particleCount) * 2 * math.pi + math.pi / _particleCount;
      final radius = maxRadius * progress * 0.7;
      final particleSize = 4.0 * (1.0 - progress);

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      canvas.drawCircle(Offset(x, y), particleSize.clamp(0.5, 4.0), smallPaint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
