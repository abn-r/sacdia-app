import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) return child;

      // Incoming: slides from right, fades in.
      final slideIn = Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      final fadeIn = CurvedAnimation(parent: animation, curve: Curves.easeOut);

      // Outgoing: slides slightly left, fades out.
      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.04, 0),
      ).animate(CurvedAnimation(
          parent: secondaryAnimation, curve: Curves.easeInCubic));

      final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
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
    },
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Fade-through — bottom-navigation tab switching
// ──────────────────────────────────────────────────────────────────────────

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
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) return child;

      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Slide-up — modal-style pages (post-registration steps, detail screens)
// ──────────────────────────────────────────────────────────────────────────

/// GoRouter [CustomTransitionPage] that slides the page up from the bottom.
///
/// Pairs with a slight scale on the outgoing page for an iOS sheet feel.
CustomTransitionPage<T> slideUpPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) return child;

      final slideIn = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      final fadeIn = CurvedAnimation(parent: animation, curve: Curves.easeOut);

      return SlideTransition(
        position: slideIn,
        child: FadeTransition(opacity: fadeIn, child: child),
      );
    },
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
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            if (MediaQuery.of(context).disableAnimations) return child;

            final slideIn = Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic));

            final fadeIn =
                CurvedAnimation(parent: animation, curve: Curves.easeOut);

            final slideOut = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.04, 0),
            ).animate(CurvedAnimation(
                parent: secondaryAnimation, curve: Curves.easeInCubic));

            final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
              CurvedAnimation(
                  parent: secondaryAnimation, curve: Curves.easeIn),
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
          },
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
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            if (MediaQuery.of(context).disableAnimations) return child;

            final slideIn = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic));

            final fadeIn =
                CurvedAnimation(parent: animation, curve: Curves.easeOut);

            return SlideTransition(
              position: slideIn,
              child: FadeTransition(opacity: fadeIn, child: child),
            );
          },
        );
}
