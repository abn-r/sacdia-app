/// Hides camporee descriptions that only repeat the event name.
///
/// "Camporee Navegando con Jesús" over a title already named that way is
/// noise. A distinct body (packing list, notes) stays visible.
bool isRedundantCamporeeDescription(String name, String? description) {
  final foldedName = _stripEventPrefix(_fold(name));
  final foldedDescription = _stripEventPrefix(_fold(description ?? ''));
  if (foldedDescription.isEmpty) return true;
  return foldedDescription == foldedName;
}

String _fold(String value) {
  final lower = value.trim().toLowerCase();
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

String _stripEventPrefix(String folded) {
  return folded
      .replaceFirst(RegExp(r'^(el |la )?(camporee|campori)\s+'), '')
      .trim();
}
