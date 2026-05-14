/// Convierte un valor en centavos enteros a texto formateado en MXN.
///
/// Ejemplos:
///   formatMxn(1000) → "$10.00"
///   formatMxn(9999) → "$99.99"
///   formatMxn(0)    → "$0.00"
String formatMxn(int centavos) {
  final pesos = centavos ~/ 100;
  final cents = centavos.remainder(100).abs();
  return '\$$pesos.${cents.toString().padLeft(2, '0')}';
}
