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
        return SacTonePalette(
          container: accent.light,
          onContainer: accent.color,
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

  /// Tinted background (icon tile, chip).
  final Color container;

  /// Icon and text on [container], and status text on a surface.
  final Color onContainer;

  /// Solid fill (bar segment, legend dot).
  final Color solid;
}
