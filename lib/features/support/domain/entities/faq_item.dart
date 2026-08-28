import 'package:equatable/equatable.dart';

/// Ítem individual del FAQ. Se carga desde `assets/support/faq.json` (bundled).
///
/// `answer` admite sintaxis Markdown simple (negritas, listas, saltos de
/// línea) — se renderiza con `flutter_markdown` en el detalle.
class FaqItem extends Equatable {
  final String id;
  final String category;
  final String question;
  final String answer;

  const FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? 'other').toString(),
      question: (json['question'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
    );
  }

  /// Case-insensitive match with Spanish accent folding
  /// (`contraseña` matches `contrasena`).
  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final q = foldForSearch(query);
    return foldForSearch(question).contains(q) ||
        foldForSearch(answer).contains(q) ||
        foldForSearch(category).contains(q);
  }

  static String foldForSearch(String input) {
    final buffer = StringBuffer();
    for (final unit in input.toLowerCase().codeUnits) {
      buffer.writeCharCode(_foldCodeUnit(unit));
    }
    return buffer.toString();
  }

  static int _foldCodeUnit(int unit) {
    switch (unit) {
      case 0xE1: // á
      case 0xE0: // à
      case 0xE2: // â
      case 0xE4: // ä
        return 0x61;
      case 0xE9: // é
      case 0xE8: // è
      case 0xEA: // ê
      case 0xEB: // ë
        return 0x65;
      case 0xED: // í
      case 0xEC: // ì
      case 0xEE: // î
      case 0xEF: // ï
        return 0x69;
      case 0xF3: // ó
      case 0xF2: // ò
      case 0xF4: // ô
      case 0xF6: // ö
        return 0x6F;
      case 0xFA: // ú
      case 0xF9: // ù
      case 0xFB: // û
      case 0xFC: // ü
        return 0x75;
      case 0xF1: // ñ
        return 0x6E;
      case 0xE7: // ç
        return 0x63;
      default:
        return unit;
    }
  }

  @override
  List<Object?> get props => [id, category, question, answer];
}
