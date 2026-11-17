import 'package:flutter/material.dart';

import '../../animations/motion_tokens.dart';
import '../../theme/app_theme.dart';

/// Equal segments, one per step. Segments before [current] are full;
/// [current] fills to [fill] (0..1); the rest are track. Screen readers get
/// one [semanticsLabel] naming the current step.
class SacStepPath extends StatelessWidget {
  const SacStepPath({
    super.key,
    required this.steps,
    required this.current,
    required this.fill,
    required this.color,
    required this.track,
    required this.labelColor,
    required this.semanticsLabel,
  });

  /// Already translated step names.
  final List<String> steps;
  final int current;
  final double fill;
  final Color color;
  final Color track;
  final Color labelColor;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Segment(
                    fill: i < current ? 1 : (i == current ? fill : 0),
                    color: color,
                    track: track,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.labelSmall,
                      fontWeight:
                          i == current ? FontWeight.w700 : FontWeight.w500,
                      color: i <= current
                          ? labelColor
                          : labelColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.fill,
    required this.color,
    required this.track,
  });

  final double fill;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.modal;
    final radius = BorderRadius.circular(AppTheme.radiusHairline);
    return Container(
      height: 4,
      decoration: BoxDecoration(color: track, borderRadius: radius),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: fill),
        duration: duration,
        curve: SacMotion.easeOut,
        builder: (context, value, _) => FractionallySizedBox(
          widthFactor: value,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, borderRadius: radius),
          ),
        ),
      ),
    );
  }
}
