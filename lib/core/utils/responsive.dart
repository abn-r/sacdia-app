import 'package:flutter/material.dart';

/// Responsive utilities for SACDIA app.
///
/// Combines Material Design 3 window size classes with Apple HIG size classes
/// for consistent cross-platform adaptation:
///
/// **Material Design 3 — Window Size Classes**
///   - Compact  (< 600dp)  — phones in portrait
///   - Medium   (< 840dp)  — large phones, small tablets, phones in landscape
///   - Expanded (>= 840dp) — tablets, desktops
///
/// **Apple HIG — Size Classes**
///   - Width:  Compact (iPhone portrait) / Regular (iPad, landscape)
///   - Height: Compact (landscape phones) / Regular (portrait)
///   - The 600dp breakpoint aligns with both systems.
class Responsive {
  Responsive._();

  // ── Material Design 3 Breakpoints ───────────────────────────────────────

  /// Minimum width for medium screens (large phones / tablets).
  static const double breakpointMedium = 600.0;

  /// Minimum width for expanded screens (tablets in landscape, desktops).
  static const double breakpointExpanded = 840.0;

  // ── Apple HIG Size Class Thresholds ─────────────────────────────────────

  /// Width threshold where Apple transitions from Compact to Regular.
  /// Coincides with Material's breakpointMedium (600dp).
  static const double appleRegularWidth = 600.0;

  /// Height threshold where Apple considers it "Compact height"
  /// (landscape phones typically < 600dp tall).
  static const double appleCompactHeight = 600.0;

  // ── Material Design 3 Screen Size Helpers ───────────────────────────────

  static bool isCompact(BuildContext context) =>
      MediaQuery.of(context).size.width < breakpointMedium;

  static bool isMedium(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= breakpointMedium && w < breakpointExpanded;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.of(context).size.width >= breakpointExpanded;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= breakpointMedium;

  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 360.0;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  // ── Apple HIG Size Class Helpers ────────────────────────────────────────

  /// Apple "Compact width" — iPhone portrait, small screens.
  static bool isCompactWidth(BuildContext context) =>
      MediaQuery.of(context).size.width < appleRegularWidth;

  /// Apple "Regular width" — iPad, large phones in landscape.
  static bool isRegularWidth(BuildContext context) =>
      MediaQuery.of(context).size.width >= appleRegularWidth;

  /// Apple "Compact height" — phones in landscape (limited vertical space).
  static bool isCompactHeight(BuildContext context) =>
      MediaQuery.of(context).size.height < appleCompactHeight;

  /// Apple "Regular height" — phones in portrait, tablets.
  static bool isRegularHeight(BuildContext context) =>
      MediaQuery.of(context).size.height >= appleCompactHeight;

  /// Returns the Apple-style size class pair as a record.
  /// Useful for switch expressions:
  /// ```dart
  /// final (w, h) = Responsive.sizeClasses(context);
  /// // w = SizeClass.compact or SizeClass.regular
  /// // h = SizeClass.compact or SizeClass.regular
  /// ```
  static (SizeClass width, SizeClass height) sizeClasses(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return (
      size.width >= appleRegularWidth ? SizeClass.regular : SizeClass.compact,
      size.height >= appleCompactHeight ? SizeClass.regular : SizeClass.compact,
    );
  }

  // ── Padding helpers ───────────────────────────────────────────────────────

  /// Horizontal screen padding that adapts to screen width.
  ///
  /// - Small phones (< 360dp) : 16px
  /// - Normal phones (< 600dp): 20px
  /// - Tablets (>= 600dp)     : 32px
  static EdgeInsets screenPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final h = width < 360 ? 16.0 : width < 600 ? 20.0 : 32.0;
    return EdgeInsets.symmetric(horizontal: h);
  }

  /// Symmetric horizontal value (double) for use in existing symmetric calls.
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 360 ? 16.0 : width < 600 ? 20.0 : 32.0;
  }

  /// Padding for auth-style forms (login / register), slightly larger.
  static EdgeInsets formPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final h = width < 360 ? 16.0 : width < 600 ? 24.0 : 40.0;
    return EdgeInsets.symmetric(horizontal: h);
  }

  // ── Max-width constraints ─────────────────────────────────────────────────

  /// Max width for single-column form content (login, register, etc.).
  static const double maxFormWidth = 480.0;

  /// Max width for content cards in expanded layout.
  static const double maxContentWidth = 680.0;

  // ── Font size helpers ─────────────────────────────────────────────────────

  /// Returns a responsive display font size.
  /// Smaller on compact phones, full size on normal phones and up.
  static double displayMediumFontSize(BuildContext context) {
    return isSmallPhone(context) ? 22.0 : 28.0;
  }

  // ── Size helpers ──────────────────────────────────────────────────────────

  /// Avatar size for header widgets — scales with screen width.
  static double headerAvatarSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return (width * 0.14).clamp(36.0, 72.0);
  }

  /// Small avatar size for in-list or welcome header widgets.
  static double smallAvatarSize(BuildContext context) {
    return isSmallPhone(context) ? 36.0 : 44.0;
  }

  /// Logo size for auth screens — smaller in landscape to save vertical space.
  static double authLogoSize(BuildContext context) {
    return isLandscape(context) ? 60.0 : 100.0;
  }

  /// Vertical spacing after the logo on auth screens.
  static double authLogoBottomSpacing(BuildContext context) {
    return isLandscape(context) ? 16.0 : 32.0;
  }

  // ── Grid helpers ──────────────────────────────────────────────────────────

  /// Maximum cross-axis extent for honor category grid cells.
  /// Results in 2 columns on phones, 3-4 on tablets.
  static const double honorGridMaxCrossAxisExtent = 200.0;
}

/// Apple HIG size class values.
///
/// Used with [Responsive.sizeClasses] to get the current
/// width and height size class as a tuple for layout decisions.
enum SizeClass {
  /// iPhone portrait width, or landscape phone height.
  compact,

  /// iPad width, or portrait phone/tablet height.
  regular,
}
