import 'package:flutter/material.dart';

/// Colores de arte decorativo del dashboard (celebración de cumpleaños).
abstract final class DashboardTokens {
  // Medallón de cumpleaños (gradiente).
  static const Color birthdayMedallionLight = Color(0xFFFFF7D6);
  static const Color birthdayMedallionMid = Color(0xFFFFD47A);

  // Texto dorado con shimmer.
  static const Color goldShimmerDeep = Color(0xFF9A650F);
  static const Color goldShimmerBase = Color(0xFFF8B84E);
  static const Color goldShimmerHighlight = Color(0xFFFFF6C7);
  static const Color goldShimmerWarm = Color(0xFFD88A18);

  // El confeti usa CelebrationTokens (lib/core/animations/).
}
