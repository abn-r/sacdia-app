import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/achievement.dart';
import '../../domain/entities/user_achievement.dart';

/// Devuelve el color del tier de un logro.
Color achievementTierColor(AchievementTier tier) => switch (tier) {
      AchievementTier.bronze => const Color(0xFFCD7F32),
      AchievementTier.silver => const Color(0xFFC0C0C0),
      AchievementTier.gold => const Color(0xFFFFD700),
      AchievementTier.platinum => const Color(0xFFE5E4E2),
      AchievementTier.diamond => const Color(0xFFB9F2FF),
      AchievementTier.unknown => Colors.grey,
    };

/// Badge visual de logro con soporte para tres estados:
/// LOCKED, IN_PROGRESS y UNLOCKED.
///
/// Especificaciones:
/// - LOCKED: imagen en escala de grises, borde gris, sin glow.
///   Si secret && !completed: muestra "???" en lugar de la imagen.
/// - IN_PROGRESS: escala de grises + [SacProgressRing] alrededor del borde.
/// - UNLOCKED: imagen a color, borde del tier (3px), glow via [BoxShadow].
///   PLATINUM: shimmer animado ciclando [tierColor, white, tierColor].
///   DIAMOND: shimmer + pulso de escala periódico en ícono de estrella.
class AchievementBadge extends StatefulWidget {
  final String? badgeImageUrl;
  final AchievementTier tier;
  final AchievementVisualState visualState;
  final bool isSecret;
  final double size;

  /// Progreso de 0.0 a 1.0 para el estado IN_PROGRESS
  final double progress;

  const AchievementBadge({
    super.key,
    required this.badgeImageUrl,
    required this.tier,
    required this.visualState,
    this.isSecret = false,
    this.size = 64,
    this.progress = 0.0,
  });

  @override
  State<AchievementBadge> createState() => _AchievementBadgeState();
}

class _AchievementBadgeState extends State<AchievementBadge>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _startAnimationsIfNeeded();
  }

  @override
  void didUpdateWidget(AchievementBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visualState != widget.visualState ||
        oldWidget.tier != widget.tier) {
      _startAnimationsIfNeeded();
    }
  }

  void _startAnimationsIfNeeded() {
    if (widget.visualState == AchievementVisualState.unlocked) {
      if (widget.tier == AchievementTier.platinum ||
          widget.tier == AchievementTier.diamond) {
        _shimmerController.repeat(reverse: true);
      } else {
        _shimmerController.stop();
      }

      if (widget.tier == AchievementTier.diamond) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    } else {
      _shimmerController.stop();
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = widget.visualState == AchievementVisualState.unlocked;
    final isInProgress = widget.visualState == AchievementVisualState.inProgress;
    final isLocked = widget.visualState == AchievementVisualState.locked;
    final tierColor = achievementTierColor(widget.tier);
    final showSecret = widget.isSecret && !isUnlocked;

    // Border color and width
    final borderColor = isUnlocked ? tierColor : context.sac.border;
    final borderWidth = isUnlocked ? 3.0 : 1.5;

    // Glow shadow only for unlocked
    final boxShadow = isUnlocked
        ? [
            BoxShadow(
              color: tierColor.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ]
        : <BoxShadow>[];

    Widget imageContent;

    final placeholderColor = context.sac.surfaceVariant;
    final placeholderTextColor = context.sac.textTertiary;

    if (showSecret) {
      // Secret achievement: show "???" text
      imageContent = Container(
        width: widget.size,
        height: widget.size,
        color: placeholderColor,
        child: Center(
          child: Text(
            '???',
            style: TextStyle(
              fontSize: widget.size * 0.28,
              fontWeight: FontWeight.w900,
              color: placeholderTextColor,
            ),
          ),
        ),
      );
    } else if (widget.badgeImageUrl != null) {
      imageContent = CachedNetworkImage(
        imageUrl: widget.badgeImageUrl!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: widget.size,
          height: widget.size,
          color: placeholderColor,
          child: Center(
            child: SizedBox(
              width: widget.size * 0.4,
              height: widget.size * 0.4,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _FallbackBadgeIcon(size: widget.size),
      );
    } else {
      imageContent = _FallbackBadgeIcon(size: widget.size);
    }

    // Apply grayscale for locked and in-progress states
    if (isLocked || isInProgress) {
      imageContent = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.grey,
          BlendMode.saturation,
        ),
        child: imageContent,
      );
    }

    // Apply shimmer for platinum and diamond unlocked
    if (isUnlocked &&
        (widget.tier == AchievementTier.platinum ||
            widget.tier == AchievementTier.diamond)) {
      imageContent = AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tierColor,
                  Colors.white,
                  tierColor,
                ],
                stops: [
                  (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                  _shimmerController.value.clamp(0.0, 1.0),
                  (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          );
        },
        child: imageContent,
      );
    }

    Widget badge = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: boxShadow,
      ),
      child: ClipOval(child: imageContent),
    );

    // Diamond: add sparkle star overlay on top
    if (isUnlocked && widget.tier == AchievementTier.diamond) {
      badge = Stack(
        alignment: Alignment.topRight,
        children: [
          badge,
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final scale =
                  1.0 + (_pulseController.value * 0.3);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size * 0.28,
                  height: widget.size * 0.28,
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedStar,
                    size: widget.size * 0.16,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    // IN_PROGRESS: circular progress overlay around the badge
    if (isInProgress) {
      badge = SizedBox(
        width: widget.size + 8,
        height: widget.size + 8,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Progress arc (drawn with CustomPaint)
            CustomPaint(
              size: Size(widget.size + 8, widget.size + 8),
              painter: _ProgressArcPainter(
                progress: widget.progress.clamp(0.0, 1.0),
                color: Colors.amber.shade600,
                trackColor: context.sac.border,
              ),
            ),
            badge,
          ],
        ),
      );
    }

    return badge;
  }
}

/// Fallback cuando no hay imagen del badge
class _FallbackBadgeIcon extends StatelessWidget {
  final double size;
  const _FallbackBadgeIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: context.sac.surfaceVariant,
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedAward01,
        size: size * 0.55,
        color: context.sac.textTertiary,
      ),
    );
  }
}

/// Painter para el arco de progreso alrededor del badge
class _ProgressArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _ProgressArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (full circle, theme-aware)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress;
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
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
  bool shouldRepaint(_ProgressArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}
