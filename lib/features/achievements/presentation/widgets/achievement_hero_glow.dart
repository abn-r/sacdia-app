import 'package:flutter/material.dart';

import 'achievement_shine.dart';

/// Hero of an obtained achievement: a soft halo in the tier colour behind
/// the badge and a band of light that crosses it every [period].
///
/// The halo is a radial gradient inside the widget's own box ([extent] times
/// the badge), so nothing is painted outside it and the scroll view never
/// cuts it. With reduced motion the halo stays and the light never passes.
class AchievementHeroGlow extends StatelessWidget {
  const AchievementHeroGlow({
    super.key,
    required this.color,
    required this.size,
    required this.child,
  });

  /// Colour of the halo (the tier colour).
  final Color color;

  /// Side of the badge.
  final double size;

  final Widget child;

  /// Side of the halo box relative to the badge.
  static const double extent = 1.3;

  /// Time between the start of one pass of light and the next.
  static const Duration period = Duration(seconds: 5);

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size * extent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.42),
                      color.withValues(alpha: 0.16),
                      color.withValues(alpha: 0),
                    ],
                    stops: const [0.25, 0.6, 1],
                  ),
                ),
              ),
            ),
          ),
          AchievementShine(period: period, child: child),
        ],
      ),
    );
  }
}
