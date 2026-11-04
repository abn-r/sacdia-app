import 'dart:ui' show FontFeature;

import 'package:intl/intl.dart';

/// Single place to format money in the app.
///
/// Amounts are always MXN, so the format is fixed to `es_MX` ("$1,234.50") on
/// purpose and does NOT follow the app language (unlike dates). The currency
/// code is never shown: "$" is enough in an MXN-only app.
abstract final class SacMoney {
  static final NumberFormat _fmt = NumberFormat.currency(
    locale: 'es_MX',
    symbol: r'$',
    decimalDigits: 2,
  );

  /// Real minus sign (U+2212), not a hyphen.
  static const String _minus = '−';

  /// Use on amount `TextStyle`s so digits align in columns.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// "$1,234.50". With [signed]: "+$1,234.50" / "−$1,234.50" (zero has no sign).
  static String format(num pesos, {bool signed = false}) {
    final cents = (pesos.abs() * 100).round();
    final body = _fmt.format(cents / 100);
    if (cents == 0) return body;
    if (pesos < 0) return signed ? '$_minus$body' : '-$body';
    return signed ? '+$body' : body;
  }

  /// Same as [format] for an integer amount in centavos.
  static String fromCentavos(int centavos, {bool signed = false}) =>
      format(centavos / 100, signed: signed);

  /// Short form for tight spaces: "$950", "$1.2k", "$12k", "$1.5M".
  static String compact(num pesos) {
    final v = pesos.abs().toDouble();
    final sign = pesos < 0 && v >= 0.5 ? _minus : '';
    if (v < 999.5) return '$sign\$${v.round()}';
    if (v < 999500) return '$sign\$${_scaled(v / 1000)}k';
    return '$sign\$${_scaled(v / 1000000)}M';
  }

  // 1 decimal below 10, none from 10 up; never a trailing ".0".
  static String _scaled(double x) {
    if (x >= 10) return x.round().toString();
    final s = x.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}
