import 'package:flutter/material.dart';

import '../theme/sac_accent.dart';
import '../theme/sac_colors.dart';

/// Semantic tone of a small tinted element (icon tile, chip, legend dot).
/// Color is never the only signal: pair it with an icon or text.
enum SacTone { accent, success, warning, info, muted, error }

/// Colors of one [SacTone], resolved from the theme.
@immutable
class SacTonePalette {
  const SacTonePalette({
    required this.container,
    required this.onContainer,
    required this.solid,
  });

  /// Resolves the palette from the current theme and accent.
  factory SacTonePalette.of(BuildContext context, SacTone tone) {
    final c = context.sac;
    switch (tone) {
      case SacTone.accent:
        final accent = SacAccent.of(context);
        if (Theme.of(context).brightness == Brightness.dark) {
          // `accent.light` is a pastel and glares on the dark theme. Same
          // recipe as SacBadge primary (DESIGN-SYSTEM §6.2): the accent
          // tinted over the dark surface, with a foreground that reads on it.
          final container = Color.alphaBlend(
            accent.color.withValues(alpha: 0.2),
            c.surface,
          );
          return SacTonePalette(
            container: container,
            // `forHighContrast` reaches 4.5:1 against black; the tile is
            // lighter than black, so lift it until it reads on the tile too.
            onContainer: _liftUntilReadable(
              accent.forHighContrast(Brightness.dark).color,
              container,
            ),
            solid: accent.color,
          );
        }
        // `accent.dark` is the shade built to read on `accent.light` (4.5:1
        // or more for every accent); `accent.color` on it drops to 1.4:1 with
        // the lighter accents. Same pairing as SacBadge primary.
        return SacTonePalette(
          container: accent.light,
          onContainer: accent.dark,
          solid: accent.color,
        );
      case SacTone.success:
        return SacTonePalette(
          container: c.successContainer,
          onContainer: c.onSuccessContainer,
          solid: c.success,
        );
      case SacTone.warning:
        return SacTonePalette(
          container: c.warningContainer,
          onContainer: c.onWarningContainer,
          solid: c.warning,
        );
      case SacTone.info:
        return SacTonePalette(
          container: c.infoContainer,
          onContainer: c.onInfoContainer,
          solid: c.info,
        );
      case SacTone.muted:
        return SacTonePalette(
          container: c.surfaceVariant,
          onContainer: c.textSecondary,
          solid: c.textTertiary,
        );
      case SacTone.error:
        return SacTonePalette(
          container: c.errorContainer,
          onContainer: c.onErrorContainer,
          solid: c.error,
        );
    }
  }

  /// Lightens [color], keeping its hue, until it reaches 4.5:1 (WCAG AA for
  /// text) against [background]. For foregrounds on a dark container.
  static Color _liftUntilReadable(Color color, Color background) {
    var hsl = HSLColor.fromColor(color);
    for (var i = 0; i < 24; i++) {
      final next = hsl.toColor();
      if (_contrast(next, background) >= 4.5) return next;
      hsl = hsl.withLightness((hsl.lightness + 0.03).clamp(0.0, 0.95));
    }
    return hsl.toColor();
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Tinted background (icon tile, chip).
  final Color container;

  /// Icon and text on [container], and status text on a surface.
  final Color onContainer;

  /// Solid fill (bar segment, legend dot).
  final Color solid;
}
