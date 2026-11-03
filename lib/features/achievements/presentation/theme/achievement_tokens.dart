import 'package:flutter/material.dart';

/// Paleta categórica de logros (tiers metálicos). No adapta a tema:
/// son colores de datos/ilustración, no superficies.
abstract final class AchievementTokens {
  // Color metálico del tier (glow, borde, fill de progreso).
  static const Color tierBronze = Color(0xFFCD7F32);
  static const Color tierSilver = Color(0xFFC0C0C0);
  static const Color tierGold = Color(0xFFFFD700);
  static const Color tierPlatinum = Color(0xFFE5E4E2);
  static const Color tierDiamond = Color(0xFFB9F2FF);

  // Tinta legible del tier para chips/labels.
  static const Color inkBronze = Color(0xFF8B5314);
  static const Color inkSilver = Color(0xFF4A5560);
  static const Color inkGold = Color(0xFF9A7200);
  static const Color inkPlatinum = Color(0xFF4E5664);
  static const Color inkDiamond = Color(0xFF0E7FA3);
  static const Color inkUnknown = Color(0xFF5A5A5A);

  // Fondo de chip — modo oscuro (se aplica con alpha).
  static const Color chipDarkSilver = Color(0xFF9AA3AD);
  static const Color chipDarkPlatinum = Color(0xFFB8BEC8);

  // Fondo de chip — modo claro.
  static const Color chipLightBronze = Color(0xFFF3D9B8);
  static const Color chipLightSilver = Color(0xFFDDE2E8);
  static const Color chipLightGold = Color(0xFFF8E7A0);
  static const Color chipLightPlatinum = Color(0xFFE2E6EC);
  static const Color chipLightDiamond = Color(0xFFC9EEF8);
  static const Color chipLightUnknown = Color(0xFFE5E5E5);

  // Base del tier en la hoja de detalle.
  static const Color detailBronze = Color(0xFFB87333);
  static const Color detailSilver = Color(0xFF8E959D);
  static const Color detailGold = Color(0xFFE0B400);
  static const Color detailPlatinum = Color(0xFF9BA3AE);
  static const Color detailDiamond = Color(0xFF5EC8E8);
}
