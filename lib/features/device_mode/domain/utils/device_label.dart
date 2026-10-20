/// Nombre con el que el tutor ve el teléfono vinculado («Tablet de Ana»).
///
/// Mismo contrato que el servidor (FP3-42): como máximo 40 caracteres y sin
/// caracteres de control. El servidor vuelve a sanearlo; esto evita mandar
/// basura y muestra al niño lo que el tutor verá.
const int kDeviceLabelMaxLength = 40;

/// Controles C0/C1, espacios de ancho cero y marcas de dirección de texto.
bool _isControlRune(int rune) =>
    rune <= 0x1F ||
    (rune >= 0x7F && rune <= 0x9F) ||
    (rune >= 0x200B && rune <= 0x200F) ||
    (rune >= 0x2028 && rune <= 0x202E) ||
    (rune >= 0x2066 && rune <= 0x2069);

String sanitizeDeviceLabel(String raw,
    {int maxLength = kDeviceLabelMaxLength}) {
  final cleaned = String.fromCharCodes(
    raw.runes.map((rune) => _isControlRune(rune) ? 0x20 : rune),
  );
  final collapsed = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = collapsed.runes.toList(growable: false);
  if (runes.length <= maxLength) return collapsed;
  return String.fromCharCodes(runes.take(maxLength)).trim();
}
