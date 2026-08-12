import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

/// One-shot opacity + mild rotateY reveal for the achievement detail badge hero.
///
/// Never loops. Respects [SacMotion.reduceMotionOf]. Animate transform/opacity
/// only — do not wrap grid badges with this widget.
class AchievementBadgeReveal extends StatefulWidget {
  final Widget child;

  const AchievementBadgeReveal({
    super.key,
    required this.child,
  });

  @override
  State<AchievementBadgeReveal> createState() => _AchievementBadgeRevealState();
}

class _AchievementBadgeRevealState extends State<AchievementBadgeReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.badgeReveal,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: SacMotion.easeOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = SacMotion.reduceMotionOf(context);
    if (_reduceMotion == reduce) return;
    final firstRead = _reduceMotion == null;
    _reduceMotion = reduce;

    if (reduce) {
      _controller.value = 1;
      return;
    }

    if (firstRead && !_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final t = _animation.value;
        final angle = (1 - t) * 0.85;
        return RepaintBoundary(
          child: Opacity(
            opacity: t,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
