import 'package:flutter/material.dart';

/// Paleta categórica de finanzas: color de acento por índice de ícono de
/// categoría. Son datos decorativos (no se adaptan al tema).
class FinanceTokens {
  FinanceTokens._();

  static const Map<int, Color> categoryAccents = {
    1: Color(0xFFF59E0B),
    2: Color(0xFF6366F1),
    3: Color(0xFF3B82F6),
    4: Color(0xFFEC4899),
    5: Color(0xFFEF4444),
    6: Color(0xFF8B5CF6),
    7: Color(0xFFF97316),
    8: Color(0xFF10B981),
    9: Color(0xFF0EA5E9),
    10: Color(0xFF64748B),
  };

  /// Acento para categorías sin color asignado.
  static const Color defaultCategoryAccent = Color(0xFF6B7280);
}
