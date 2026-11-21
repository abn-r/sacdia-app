import 'package:flutter/material.dart';

/// How a badge or patch is drawn in a grid card.
///
/// - [color]: the art as is (obtained, or no longer valid).
/// - [dimmed]: full colour at reduced opacity (a mastery in progress).
/// - [muted]: grey and faded (not obtained, or no progress yet).
enum SacBadgeTone {
  color(gray: 0, opacity: 1),
  dimmed(gray: 0, opacity: 0.62),
  muted(gray: 1, opacity: 0.42);

  const SacBadgeTone({required this.gray, required this.opacity});

  /// 0 keeps the colours, 1 is fully grey.
  final double gray;
  final double opacity;
}

/// Greys and fades [child] by [gray] (0..1) and [opacity]. Never reshapes
/// the art: badges keep their own silhouette.
class SacBadgeTint extends StatelessWidget {
  const SacBadgeTint({
    super.key,
    required this.gray,
    required this.opacity,
    required this.child,
  });

  SacBadgeTint.tone({
    Key? key,
    required SacBadgeTone tone,
    required Widget child,
  }) : this(
          key: key,
          gray: tone.gray,
          opacity: tone.opacity,
          child: child,
        );

  final double gray;
  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    if (opacity < 1) result = Opacity(opacity: opacity, child: result);
    if (gray > 0) {
      // A colour matrix, not BlendMode.saturation: that mode leaks out of the
      // badge and greys the whole grid.
      result = ColorFiltered(colorFilter: _grayFilter(gray), child: result);
    }
    return result;
  }
}

ColorFilter _grayFilter(double amount) {
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final keep = 1 - amount;
  final g = amount;
  return ColorFilter.matrix(<double>[
    keep + g * lr, g * lg, g * lb, 0, 0, //
    g * lr, keep + g * lg, g * lb, 0, 0,
    g * lr, g * lg, keep + g * lb, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}
