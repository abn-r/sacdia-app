import 'package:flutter/material.dart';

import '../../domain/entities/achievement.dart';
import 'achievement_badge.dart';

/// Barra de progreso para logros con color del tier.
///
/// Versión especializada de SacProgressBar que usa el color del tier
/// como fill en lugar del gradiente primario/secundario del design system.
class AchievementProgressBar extends StatefulWidget {
  /// Progreso de 0.0 a 1.0
  final double progress;

  /// Tier para determinar el color de relleno
  final AchievementTier tier;

  /// Altura de la barra
  final double height;

  /// Label opcional (ej. "3/5")
  final String? label;

  const AchievementProgressBar({
    super.key,
    required this.progress,
    required this.tier,
    this.height = 6.0,
    this.label,
  });

  @override
  State<AchievementProgressBar> createState() => _AchievementProgressBarState();
}

class _AchievementProgressBarState extends State<AchievementProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fillAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AchievementProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      final current = _fillAnimation.value;
      _fillAnimation = Tween<double>(
        begin: current,
        end: widget.progress.clamp(0.0, 1.0),
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
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
    final tierColor = achievementTierColor(widget.tier);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: widget.height,
              child: AnimatedBuilder(
                animation: _fillAnimation,
                builder: (context, _) {
                  return Stack(
                    children: [
                      // Track background
                      Container(
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      // Filled portion with tier color
                      FractionallySizedBox(
                        widthFactor: _fillAnimation.value,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: tierColor,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(width: 8),
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tierColor,
            ),
          ),
        ],
      ],
    );
  }
}
