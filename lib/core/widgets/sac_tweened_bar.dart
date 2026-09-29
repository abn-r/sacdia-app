import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

/// Determinate bar that eases to a new value.
///
/// The first paint shows [value]. Later changes tween with
/// [SacMotion.standard] and [SacMotion.easeOut]. Reduced Motion jumps
/// to the target.
class SacTweenedBar extends StatelessWidget {
  const SacTweenedBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.minHeight = 4,
    this.borderRadius = 4,
  });

  /// Progress from 0 to 1.
  final double value;
  final Color color;
  final Color backgroundColor;
  final double minHeight;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    final reduce = SacMotion.reduceMotionOf(context);
    if (reduce) return _bar(target);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: SacMotion.standard,
      curve: SacMotion.easeOut,
      builder: (context, shown, _) => _bar(shown),
    );
  }

  Widget _bar(double shown) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: LinearProgressIndicator(
        value: shown,
        minHeight: minHeight,
        backgroundColor: backgroundColor,
        color: color,
      ),
    );
  }
}
