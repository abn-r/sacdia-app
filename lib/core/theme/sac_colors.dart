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
  Color get ink800 => _isDark ? const Color(0xFFE4E4E4) : const Color(0xFF20232A);
  Color get ink700 => _isDark ? const Color(0xFFCFCFCF) : const Color(0xFF2C313B);
  Color get ink600 => _isDark ? const Color(0xFFB8B8B8) : const Color(0xFF4B5260);
  Color get ink500 => _isDark ? const Color(0xFF9A9A9A) : const Color(0xFF6B7280);
  Color get ink400 => _isDark ? const Color(0xFF7A7A7A) : const Color(0xFF9AA0AB);
  Color get ink300 => _isDark ? const Color(0xFF4A4A4A) : const Color(0xFFC7CBD2);
  Color get ink200 => _isDark ? const Color(0xFF383838) : const Color(0xFFE3E5EA);
  Color get ink150 => _isDark ? AppColors.darkBorder : const Color(0xFFECEEF2);
  Color get ink100 => _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F7);
  Color get ink50 =>
      _isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF7F8FA);

  /// Superficie de tarjeta / app bar (blanco en light).
  Color get paper => _isDark ? AppColors.darkSurface : const Color(0xFFFFFFFF);

  /// Fondo de pantalla (gris casi blanco en light, negro OLED en dark).
  Color get canvas =>
      _isDark ? AppColors.darkBackground : const Color(0xFFFAFAFB);

  // ── Elevation / Shadow ────────────────────────────────────────
  Color get shadow => _isDark
      ? Colors.white.withValues(alpha: 0.04)
      : Colors.black.withValues(alpha: 0.08);

  // ── On-surface ────────────────────────────────────────────────
  Color get onPrimary => Colors.white;

  // ── Semantic state colors ─────────────────────────────────────
  // Use these getters for all status/feedback paint code.
  // NEVER use AppColors.success / AppColors.error / etc. directly
  // in widget paint code — those are light-mode only and do not
  // adapt to dark mode. These getters do.

  Color get success => AppColors.secondary; // #4FBF9F — same value both modes
  Color get onSuccess => Colors.white;

  Color get warning => AppColors.accent; // #FBBD5E — same value both modes
  Color get onWarning => AppColors.accentDark; // dark text on yellow bg

  Color get info => AppColors.info; // #2EA0DA — same value both modes
  Color get onInfo => Colors.white;

  Color get error => AppColors.error; // #DC2626 — same value both modes
  Color get onError => Colors.white;

  // ── Overlays ──────────────────────────────────────────────────
  Color get barrierColor => _isDark
      ? Colors.black.withValues(alpha: 0.7)
      : Colors.black.withValues(alpha: 0.5);
}
