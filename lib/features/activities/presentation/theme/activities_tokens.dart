import 'package:flutter/material.dart';

/// Tokens de datos de la feature Actividades.
///
/// Paletas categóricas (no se adaptan a tema): se usan para colorear los
/// avatares de asistentes. El tono base se usa como fondo (con alpha) y el
/// tono oscuro como color del texto.
class ActivitiesTokens {
  ActivitiesTokens._();

  /// Fondos de avatar de asistente (tonos 500).
  static const List<Color> attendeeAvatarPalette = [
    Color(0xFFF59E0B), // amber-500
    Color(0xFFF43F5E), // rose-500
    Color(0xFF0EA5E9), // sky-500
    Color(0xFF8B5CF6), // violet-500
    Color(0xFF10B981), // emerald-500
    Color(0xFFEF4444), // red-500
    Color(0xFF3B82F6), // blue-500
    Color(0xFFEC4899), // pink-500
  ];

  /// Texto de las iniciales de avatar (tonos 600).
  static const List<Color> attendeeAvatarPaletteDark = [
    Color(0xFFD97706), // amber-600
    Color(0xFFE11D48), // rose-600
    Color(0xFF0284C7), // sky-600
    Color(0xFF7C3AED), // violet-600
    Color(0xFF059669), // emerald-600
    Color(0xFFDC2626), // red-600
    Color(0xFF2563EB), // blue-600
    Color(0xFFDB2777), // pink-600
  ];
}
