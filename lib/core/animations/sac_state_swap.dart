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
    this.overlapOutgoing = true,
  });

  final Widget child;

  /// Duration when motion is allowed. Reduced Motion uses [SacMotion.reducedFade].
  final Duration duration;

  /// Whether the outgoing child stays painted while it fades out. Pass `false`
  /// when both faces cannot share the same spot (a button label and its
  /// spinner): the outgoing child is dropped at once and only the incoming one
  /// fades in.
  final bool overlapOutgoing;

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    return AnimatedSwitcher(
      duration: reduce ? SacMotion.reducedFade : duration,
      switchInCurve: SacMotion.easeOut,
      switchOutCurve: SacMotion.easeOut,
      layoutBuilder: overlapOutgoing
          ? AnimatedSwitcher.defaultLayoutBuilder
          : (currentChild, _) => currentChild ?? const SizedBox.shrink(),
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
