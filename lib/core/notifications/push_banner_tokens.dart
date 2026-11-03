import 'package:flutter/material.dart';

/// Achievement tier accents for the in-app push banner.
///
/// The banner is always dark, so these are tuned for a dark background in
/// both themes.
abstract final class PushBannerTokens {
  static const Color tierDiamond = Color(0xFF7DD3FC);
  static const Color tierPlatinum = Color(0xFFE5E7EB);
  static const Color tierGold = Color(0xFFFBBF24);
  static const Color tierSilver = Color(0xFFD1D5DB);
  static const Color tierBronze = Color(0xFFD97706);
}
