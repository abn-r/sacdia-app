import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Tonal pair built from a class color (`AppColors.classColor`).
///
/// Class colors range from pale yellow to navy, so none of them can carry
/// text as a solid fill. This derives a soft [container] tint and an
/// [onContainer] shade of the same hue that reads at 4.5:1 or better on the
/// container and on the card surface, in light and dark mode.
@immutable
class ClassTone {
  const ClassTone({required this.container, required this.onContainer});

  /// Tint for tonal buttons and chips.
  final Color container;

  /// Text and icons on [container], or class-colored text on the card.
  final Color onContainer;

  static const double minContrast = 4.5;

  static ClassTone of(BuildContext context, Color classColor) {
    return resolve(
      classColor,
      surface: context.sac.surface,
      brightness: Theme.of(context).brightness,
    );
  }

  static ClassTone resolve(
    Color classColor, {
    required Color surface,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final container = Color.alphaBlend(
      classColor.withValues(alpha: isDark ? 0.22 : 0.16),
      surface,
    );

    // Walk the lightness away from the backgrounds until both pass.
    final hsl = HSLColor.fromColor(classColor);
    var lightness = hsl.lightness;
    var onContainer = classColor;
    while (_contrast(onContainer, container) < minContrast ||
        _contrast(onContainer, surface) < minContrast) {
      lightness += isDark ? 0.02 : -0.02;
      if (lightness <= 0 || lightness >= 1) {
        onContainer = isDark ? Colors.white : const Color(0xFF131316);
        break;
      }
      onContainer = hsl.withLightness(lightness).toColor();
    }

    return ClassTone(container: container, onContainer: onContainer);
  }

  static double contrast(Color a, Color b) => _contrast(a, b);

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final top = la > lb ? la : lb;
    final bottom = la > lb ? lb : la;
    return (top + 0.05) / (bottom + 0.05);
  }
}
