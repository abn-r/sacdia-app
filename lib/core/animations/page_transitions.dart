import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'motion_tokens.dart';

/// Custom page route transitions for GoRouter.
///
/// Provides three transition styles used throughout the app:
///   - [SacFadeThroughTransition]  — cross-fade (tab switches)
///   - [SacSharedAxisTransition]   — horizontal slide (forward/back navigation)
///   - [SacSlideUpTransition]      — slide-up from bottom (sheets, modals as pages)
///
/// All transitions are under 400 ms and respect [MediaQuery.disableAnimations].

// ──────────────────────────────────────────────────────────────────────────
// Shared-axis (horizontal slide) — forward / back navigation
// ──────────────────────────────────────────────────────────────────────────

Widget _buildSharedAxisTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final reduceMotion = SacMotion.reduceMotionOf(context);
  final slideIn = Tween<Offset>(
    begin: reduceMotion ? Offset.zero : const Offset(0.04, 0),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: animation,
      curve: SacMotion.easeOut,
      reverseCurve: const FlippedCurve(SacMotion.easeOut),
    ),
  );
  final fadeIn = CurvedAnimation(
    parent: animation,
    curve: SacMotion.easeOut,
    reverseCurve: const FlippedCurve(SacMotion.easeOut),
  );

  final slideOut = Tween<Offset>(
    begin: Offset.zero,
    end: reduceMotion ? Offset.zero : const Offset(-0.03, 0),
  ).animate(
    CurvedAnimation(
      parent: secondaryAnimation,
      curve: SacMotion.easeOut,
      reverseCurve: const FlippedCurve(SacMotion.easeOut),
    ),
  );
  final fadeOut = Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(
      parent: secondaryAnimation,
      curve: SacMotion.easeOut,
      reverseCurve: const FlippedCurve(SacMotion.easeOut),
    ),
  );

  return SlideTransition(
    position: slideOut,
    child: FadeTransition(
      opacity: fadeOut,
      child: SlideTransition(
        position: slideIn,
        child: FadeTransition(opacity: fadeIn, child: child),
      ),
    ),
  );
}

/// GoRouter [CustomTransitionPage] with a horizontal shared-axis slide.
///
/// Incoming page slides in from the right and fades in simultaneously.
/// Outgoing page slides out to the left and fades out.
CustomTransitionPage<T> sharedAxisPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: SacMotion.routeEnter,
    reverseTransitionDuration: SacMotion.routeExit,
    transitionsBuilder: _buildSharedAxisTransition,
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Fade-through — bottom-navigation tab switching
// ──────────────────────────────────────────────────────────────────────────

Widget _buildFadeThroughTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: SacMotion.easeOut,
      reverseCurve: const FlippedCurve(SacMotion.easeOut),
    ),
    child: child,
  );
}

/// GoRouter [CustomTransitionPage] with a pure cross-fade.
///
/// Ideal for bottom-navigation tab switches where no directional cue is needed.
CustomTransitionPage<T> fadeThroughPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: SacMotion.reducedFade,
    reverseTransitionDuration: SacMotion.reducedFade,
    transitionsBuilder: _buildFadeThroughTransition,
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Slide-up — modal-style pages (post-registration steps, detail screens)
// ──────────────────────────────────────────────────────────────────────────

Widget _buildSlideUpTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final reduceMotion = SacMotion.reduceMotionOf(context);
  final slideIn = Tween<Offset>(
    begin: reduceMotion ? Offset.zero : const Offset(0, 1),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: animation,
      curve: SacMotion.drawer,
      reverseCurve: const FlippedCurve(SacMotion.drawer),
    ),
  );
  final fadeIn = CurvedAnimation(
    parent: animation,
    curve: SacMotion.easeOut,
    reverseCurve: const FlippedCurve(SacMotion.easeOut),
  );

  return SlideTransition(
    position: slideIn,
    child: FadeTransition(opacity: fadeIn, child: child),
  );
}

/// GoRouter [CustomTransitionPage] that slides the page up from the bottom.
///
CustomTransitionPage<T> slideUpPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: SacMotion.routeEnter,
    reverseTransitionDuration: SacMotion.routeExit,
    transitionsBuilder: _buildSlideUpTransition,
  );
}

// ──────────────────────────────────────────────────────────────────────────
// MaterialPageRoute drop-in replacements (for Navigator.push usage)
// ──────────────────────────────────────────────────────────────────────────

/// A [PageRoute] that applies a horizontal shared-axis slide.
///
/// Use as a drop-in for [MaterialPageRoute] when pushing via [Navigator].
/// ```dart
/// Navigator.push(context, SacSharedAxisRoute(builder: (_) => MyPage()));
/// ```
class SacSharedAxisRoute<T> extends PageRouteBuilder<T> {
  SacSharedAxisRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: SacMotion.routeEnter,
          reverseTransitionDuration: SacMotion.routeExit,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: _buildSharedAxisTransition,
        );
}

/// A [PageRoute] that applies an opacity-only fade-through transition.
class SacFadeThroughRoute<T> extends PageRouteBuilder<T> {
  SacFadeThroughRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: SacMotion.reducedFade,
          reverseTransitionDuration: SacMotion.reducedFade,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: _buildFadeThroughTransition,
        );
}

/// A [PageRoute] that slides the new page up from the bottom.
///
/// ```dart
/// Navigator.push(context, SacSlideUpRoute(builder: (_) => DetailPage()));
/// ```
class SacSlideUpRoute<T> extends PageRouteBuilder<T> {
  SacSlideUpRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: SacMotion.routeEnter,
          reverseTransitionDuration: SacMotion.routeExit,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: _buildSlideUpTransition,
        );
}
