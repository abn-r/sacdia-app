/// Font size scale of the SACDIA design system (v2).
///
/// Each role in the app's `TextTheme` takes its size from this class, so
/// `Theme.of(context).textTheme.bodyMedium` and
/// `TextStyle(fontSize: SacFontSize.bodyMedium)` always match.
///
/// Prefer a `textTheme` style. Use these constants only when a widget needs a
/// custom `TextStyle` (its own weight, tracking or color). A literal
/// `fontSize:` outside `lib/core/theme/` fails
/// `test/core/theme/design_tokens_guard_test.dart`.
///
/// The scale follows the sizes the app's screens already use, which match
/// Apple's type scale (the app renders in SF Pro).
abstract final class SacFontSize {
  /// Digits inside very small badges and avatar overlays.
  static const double nano = 7;

  /// Compact badges and chart axis labels.
  static const double micro = 9;

  /// Smallest regular text: footnotes and dense captions.
  static const double caption = 10;

  /// Eyebrows, section labels and micro labels (`labelSmall`).
  static const double labelSmall = 11;

  /// Metadata and subtitles (`bodySmall`, `labelMedium`).
  static const double bodySmall = 12;

  /// Standard body and secondary text (`bodyMedium`).
  static const double bodyMedium = 13;

  /// Compact titles and button labels (`titleSmall`, `labelLarge`).
  static const double titleSmall = 14;

  /// List-row titles and long-form body (`titleMedium`, `bodyLarge`).
  static const double titleMedium = 15;

  /// Card titles (`titleLarge`).
  static const double titleLarge = 17;

  /// Sub-section headers (`headlineSmall`).
  static const double headlineSmall = 18;

  /// Card headers and app bar titles (`headlineMedium`).
  static const double headlineMedium = 20;

  /// Section headers (`headlineLarge`).
  static const double headlineLarge = 22;

  /// Section titles (`displaySmall`).
  static const double displaySmall = 24;

  /// Screen main titles (`displayMedium`).
  static const double displayMedium = 28;

  /// Hero headers and splash (`displayLarge`).
  static const double displayLarge = 32;

  /// Large figures in summary cards (balances, scores, stats).
  static const double metricSmall = 36;

  /// Hero figures, such as a class progress percentage.
  static const double metric = 44;
}
