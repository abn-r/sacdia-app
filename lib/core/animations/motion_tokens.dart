import 'package:flutter/material.dart';

abstract final class SacMotion {
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);

  static const Duration press = Duration(milliseconds: 140);
  static const Duration reducedFade = Duration(milliseconds: 160);
  static const Duration switcher = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration routeEnter = Duration(milliseconds: 240);
  static const Duration routeExit = Duration(milliseconds: 200);
  static const Duration modal = Duration(milliseconds: 240);

  /// Horizontal slide of a swapped content (day change in the agenda) and of
  /// the segmented control thumb.
  static const Duration slide = Duration(milliseconds: 220);
  static const double slideOffset = 24;
  static const Duration stagger = Duration(milliseconds: 40);

  /// Data reveal on screen open: progress bars filling and counters counting
  /// up together. Long enough to read as "progress", only on first build or
  /// when the value changes.
  static const Duration reveal = Duration(milliseconds: 600);

  /// Section entrance on content screens (fade + slide up).
  static const Duration entrance = Duration(milliseconds: 320);
  static const Duration entranceStagger = Duration(milliseconds: 60);
  static const double entranceOffset = 12;

  /// Decorative idle drift on rare surfaces (login constellation).
  /// 3200ms ≈ 0.31 Hz — keep away from ~0.2 Hz / 5000ms.
  static const Duration idleDrift = Duration(milliseconds: 3200);

  static const double enterScale = 0.96;
  static const double pressScale = 0.97;

  /// Press scale for wide surfaces (cards, status panel): less travel so the
  /// whole surface does not jump.
  static const double panelPressScale = 0.98;

  /// Press scale for list rows.
  static const double rowPressScale = 0.985;

  /// Press scale for small tiles (the "Agregar" tile).
  static const double tilePressScale = 0.95;

  /// One-off nudge of the "sent" icon (M4).
  static const Duration nudge = Duration(milliseconds: 320);

  /// Stroke reveal of the validated check (M6).
  static const Duration draw = Duration(milliseconds: 300);

  /// Single pulse of the class percentage at 100 % (M7).
  static const Duration pulse = Duration(milliseconds: 420);

  /// One ring on the current state dot (M5) and the sheen sweep (M7).
  static const Duration ring = Duration(milliseconds: 700);

  static bool reduceMotionOf(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
