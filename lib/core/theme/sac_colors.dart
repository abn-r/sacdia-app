import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Extension on [BuildContext] that resolves semantic color tokens
/// to their light or dark variant based on the current [Brightness].
///
/// Usage:
/// ```dart
/// final bg = context.sac.background;
/// final text = context.sac.text;
/// ```
///
/// This avoids hardcoding `AppColors.lightText` / `AppColors.darkText`
/// everywhere and makes dark-mode support automatic.
extension SacColorsExtension on BuildContext {
  SacColors get sac => SacColors(Theme.of(this).brightness);
}

class SacColors {
  final Brightness _brightness;

  const SacColors(this._brightness);

  bool get _isDark => _brightness == Brightness.dark;

  // ── Surfaces ──────────────────────────────────────────────────
  Color get background =>
      _isDark ? AppColors.darkBackground : AppColors.lightBackground;

  Color get surface => _isDark ? AppColors.darkSurface : AppColors.lightSurface;

  Color get surfaceVariant =>
      _isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;

  // ── Borders ───────────────────────────────────────────────────
  Color get border => _isDark ? AppColors.darkBorder : AppColors.lightBorder;

  Color get borderLight =>
      _isDark ? AppColors.darkSurfaceVariant : AppColors.lightBorderLight;

  Color get divider => _isDark ? AppColors.darkDivider : AppColors.lightDivider;

  // ── Text ──────────────────────────────────────────────────────
  Color get text => _isDark ? AppColors.darkText : AppColors.lightText;

  Color get textSecondary =>
      _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  Color get textTertiary =>
      _isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

  // ── Escala neutra "ink" (resuelta por tema) ───────────────────
  // Reemplazo directo de `AppColors.inkNNN` / `paper` / `canvas`, que son
  // light-only. La semántica es "fuerza de tinta": ink900 = texto principal,
  // ink500 = secundario, ink150 = borde, ink50 = fondo de fila. En dark la
  // escala se invierte para conservar el mismo contraste relativo; los
  // extremos se alinean con `AppColors.dark*`.
  Color get ink900 => _isDark ? AppColors.darkText : const Color(0xFF131316);
  Color get ink800 =>
      _isDark ? const Color(0xFFE4E4E4) : const Color(0xFF20232A);
  Color get ink700 =>
      _isDark ? const Color(0xFFCFCFCF) : const Color(0xFF2C313B);
  Color get ink600 =>
      _isDark ? const Color(0xFFB8B8B8) : const Color(0xFF4B5260);
  Color get ink500 =>
      _isDark ? const Color(0xFF9A9A9A) : const Color(0xFF6B7280);
  Color get ink400 =>
      _isDark ? const Color(0xFF7A7A7A) : const Color(0xFF9AA0AB);
  Color get ink300 =>
      _isDark ? const Color(0xFF4A4A4A) : const Color(0xFFC7CBD2);
  Color get ink200 =>
      _isDark ? const Color(0xFF383838) : const Color(0xFFE3E5EA);
  Color get ink150 => _isDark ? AppColors.darkBorder : const Color(0xFFECEEF2);
  Color get ink100 =>
      _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F7);
  Color get ink50 =>
      _isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF7F8FA);

  /// Superficie de tarjeta / app bar (blanco en light).
  Color get paper => _isDark ? AppColors.darkSurface : const Color(0xFFFFFFFF);

  /// Fondo de pantalla (gris casi blanco en light, negro OLED en dark).
  Color get canvas =>
      _isDark ? AppColors.darkBackground : const Color(0xFFFAFAFB);

  // ── Elevation / Shadow ────────────────────────────────────────
  // ── Loading skeletons ─────────────────────────────────────────
  /// Base fill of loading skeleton blocks.
  Color get skeleton =>
      _isDark ? AppColors.darkSkeleton : const Color(0xFFECEEF2);

  /// Card or container behind skeleton blocks. Stays darker than
  /// [skeleton] in dark mode so the blocks keep their contrast.
  Color get skeletonSurface =>
      _isDark ? AppColors.darkSurface : const Color(0xFFF7F8FA);

  /// Lighter fill for nested or alternating skeleton blocks.
  Color get skeletonHighlight =>
      _isDark ? AppColors.darkSkeletonHighlight : const Color(0xFFF7F8FA);

  Color get shadow => _isDark
      ? Colors.white.withValues(alpha: 0.04)
      : Colors.black.withValues(alpha: 0.08);

  // ── On-surface ────────────────────────────────────────────────
  Color get onPrimary => Colors.white;

  // ── Semantic state colors ─────────────────────────────────────
  // Solid fills (`success`, `warning`, `info`, `error`) have the same value
  // in both modes. The light-only colors are the `AppColors.*Light` /
  // `light*` pastels: do not use those in widget paint code.
  //
  // `onX` is ONLY for text/icons painted on a solid `x` fill.
  // `xContainer` / `onXContainer` are the tinted pair for badges, banners and
  // status cards. `onXContainer` is for text/icons on the container AND for
  // status-colored text directly on `surface`/`background` (verified >= 5.4:1
  // on white and on #1A1A1A/#000).

  Color get success => AppColors.secondary; // #4FBF9F — same value both modes
  Color get onSuccess => const Color(0xFF131316); // ink on solid green, 8.2:1
  Color get successContainer =>
      _isDark ? const Color(0xFF253B35) : const Color(0xFFE0F5EF);
  Color get onSuccessContainer =>
      _isDark ? const Color(0xFF6FD3B6) : const Color(0xFF1E6B55);

  Color get warning => AppColors.accent; // #FBBD5E — same value both modes
  Color get onWarning => const Color(0xFF131316); // ink on solid yellow, 11.1:1
  Color get warningContainer =>
      _isDark ? const Color(0xFF473B28) : const Color(0xFFFFF4E0);
  Color get onWarningContainer =>
      _isDark ? const Color(0xFFFBBD5E) : const Color(0xFF8A5A00);

  Color get info => AppColors.info; // #2EA0DA — same value both modes
  Color get onInfo => const Color(0xFF131316); // ink on solid blue, 6.3:1
  Color get infoContainer =>
      _isDark ? const Color(0xFF1E3540) : const Color(0xFFEFF6FF);
  Color get onInfoContainer =>
      _isDark ? const Color(0xFF7CC4EE) : const Color(0xFF0B6699);

  Color get error => AppColors.error; // #DC2626 — same value both modes
  Color get onError => Colors.white; // 4.83:1 on solid red
  Color get errorContainer =>
      _isDark ? const Color(0xFF491D1D) : const Color(0xFFFEE2E2);
  Color get onErrorContainer =>
      _isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);

  // ── Overlays ──────────────────────────────────────────────────
  Color get barrierColor => _isDark
      ? Colors.black.withValues(alpha: 0.7)
      : Colors.black.withValues(alpha: 0.5);
}
