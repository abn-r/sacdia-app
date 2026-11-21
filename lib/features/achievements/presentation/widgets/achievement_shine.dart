import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

/// A band of light that crosses [child] diagonally every [period], painted
/// only where the child is opaque (the badge, never its background).
///
/// Between passes nothing animates: the pass runs on a short controller and
/// a timer waits for the next one, so a grid full of obtained badges costs
/// nothing while they rest.
///
/// With reduced motion the light never passes.
class AchievementShine extends StatefulWidget {
  const AchievementShine({
    super.key,
    required this.period,
    required this.child,
    this.initialDelay = const Duration(seconds: 1),
  });

  /// Time between the start of one pass and the next.
  final Duration period;

  /// Wait before the first pass, so it does not fight the screen entering.
  final Duration initialDelay;

  final Widget child;

  /// How long one pass takes.
  static const Duration sweep = Duration(milliseconds: 1100);

  @override
  State<AchievementShine> createState() => _AchievementShineState();
}

class _AchievementShineState extends State<AchievementShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pass;
  Timer? _next;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _pass = AnimationController(vsync: this, duration: AchievementShine.sweep)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _schedule(widget.period - AchievementShine.sweep);
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = SacMotion.reduceMotionOf(context);
    if (still == _still && (_next != null || _pass.isAnimating)) return;
    _still = still;
    if (_still) {
      _next?.cancel();
      _next = null;
      _pass
        ..stop()
        ..value = 0;
    } else if (_next == null && !_pass.isAnimating) {
      _schedule(widget.initialDelay);
    }
  }

  void _schedule(Duration wait) {
    _next?.cancel();
    _next = Timer(wait, () {
      _next = null;
      if (!mounted || _still) return;
      _pass.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _next?.cancel();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pass,
      child: widget.child,
      builder: (context, child) {
        if (!_pass.isAnimating) return child!;
        final t = SacMotion.easeInOut.transform(_pass.value);
        // Centre of the band: from fully left of the badge to fully right.
        final position = -1.6 + t * 3.2;
        return ShaderMask(
          // srcATop keeps the child's own alpha: the light only lands on
          // the badge, never on what is around it.
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(position - 0.6, -1),
            end: Alignment(position + 0.6, 1),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.3, 0.5, 0.7],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
