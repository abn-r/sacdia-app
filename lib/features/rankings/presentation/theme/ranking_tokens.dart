import 'package:flutter/material.dart';

/// Paleta categórica de rankings (tiers de premio y de ranking).
abstract final class RankingTokens {
  // Premios (AwardTier).
  static const Color awardBronze = Color(0xFFCD7F32);
  static const Color awardSilver = Color(0xFFC0C0C0);
  static const Color awardGold = Color(0xFFFFD700);
  static const Color awardDiamond = Color(0xFFB9F2FF);

  // Tiers de ranking: [light, dark] legibles sobre surface clara/oscura.
  static const Color tierSilverLight = Color(0xFF5B6B7C);
  static const Color tierSilverDark = Color(0xFFA3B1C2);
  static const Color tierGoldLight = Color(0xFF9A6B18);
  static const Color tierGoldDark = Color(0xFFE0B341);
  static const Color tierDiamondLight = Color(0xFF0E7490);
  static const Color tierDiamondDark = Color(0xFF22D3EE);
  static const Color tierBronzeLight = Color(0xFFB86A2D);
  static const Color tierBronzeDark = Color(0xFFD28C52);
}
