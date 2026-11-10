import 'package:flutter/material.dart';

/// How strong the auth sky wash is. The welcome carousel opens and closes
/// on [hero]; its middle scenes use [soft]; the auth forms use [regular].
enum AuthSkyStrength { hero, regular, soft }

/// Decorative tokens for the auth flow (welcome carousel and auth forms).
class AuthTokens {
  const AuthTokens._();

  /// Top alpha of the sky wash per strength, light and dark.
  /// Dark mode keeps the wash low so it never reads as a solid blue slab.
  static double skyAlpha(AuthSkyStrength strength, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (strength) {
      AuthSkyStrength.hero => dark ? 0.34 : 0.65,
      AuthSkyStrength.regular => dark ? 0.26 : 0.5,
      AuthSkyStrength.soft => dark ? 0.2 : 0.4,
    };
  }

  /// Where the sky wash fades out, as a fraction of the height.
  static const double skyFadeEnd = 0.42;

  /// Warm radial wash, centre and edge stops.
  static const Color washGold = Color(0x1CFFB020);
  static const Color washGoldClear = Color(0x00FFB020);

  /// Cool radial wash, centre and edge stops.
  static const Color washBlue = Color(0x140B84F0);
  static const Color washBlueClear = Color(0x000B84F0);

  /// Hero tag shared by the brand mark at the end of the welcome carousel
  /// and the brand mark on the login screen.
  static const String brandMarkHeroTag = 'sacdia-brand-mark';
}
