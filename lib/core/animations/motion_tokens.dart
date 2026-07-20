import 'package:flutter/material.dart';

abstract final class SacMotion {
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);

  static const Duration press = Duration(milliseconds: 140);
  static const Duration reducedFade = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration routeEnter = Duration(milliseconds: 240);
  static const Duration routeExit = Duration(milliseconds: 200);
  static const Duration modal = Duration(milliseconds: 240);
  static const Duration stagger = Duration(milliseconds: 40);

  static const double enterScale = 0.96;

  static bool reduceMotionOf(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
