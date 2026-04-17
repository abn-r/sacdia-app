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

  Color get surface =>
      _isDark ? AppColors.darkSurface : AppColors.lightSurface;

  Color get surfaceVariant =>
      _isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;

  // ── Borders ───────────────────────────────────────────────────
  Color get border =>
      _isDark ? AppColors.darkBorder : AppColors.lightBorder;

  Color get borderLight =>
      _isDark ? AppColors.darkSurfaceVariant : AppColors.lightBorderLight;

  Color get divider =>
      _isDark ? AppColors.darkDivider : AppColors.lightDivider;

  // ── Text ──────────────────────────────────────────────────────
  Color get text =>
      _isDark ? AppColors.darkText : AppColors.lightText;

  Color get textSecondary =>
      _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  Color get textTertiary =>
      _isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

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

  Color get info => AppColors.sacBlue; // #2EA0DA — same value both modes
  Color get onInfo => Colors.white;

  Color get error => AppColors.error; // #DC2626 — same value both modes
  Color get onError => Colors.white;

  // ── Overlays ──────────────────────────────────────────────────
  Color get barrierColor => _isDark
      ? Colors.black.withValues(alpha: 0.7)
      : Colors.black.withValues(alpha: 0.5);
}
