import 'package:flutter/material.dart';

import 'motion_tokens.dart';

/// Crossfade for a control that changes state.
///
/// The [child] needs a [Key] that changes with the state. Reduced Motion
/// keeps the fade and drops the scale.
class SacStateSwap extends StatelessWidget {
  const SacStateSwap({
    super.key,
    required this.child,
    this.duration = SacMotion.switcher,
  });

  final Widget child;

  /// Duration when motion is allowed. Reduced Motion uses [SacMotion.reducedFade].
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    return AnimatedSwitcher(
      duration: reduce ? SacMotion.reducedFade : duration,
      switchInCurve: SacMotion.easeOut,
      switchOutCurve: SacMotion.easeOut,
      transitionBuilder: (child, animation) {
        final fade = FadeTransition(opacity: animation, child: child);
        if (reduce) return fade;
        return ScaleTransition(
          scale: Tween<double>(
            begin: SacMotion.enterScale,
            end: 1,
          ).animate(animation),
          child: fade,
        );
      },
      child: child,
    );
  }
}
