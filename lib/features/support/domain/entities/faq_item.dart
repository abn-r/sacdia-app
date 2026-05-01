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

  /// Coincidencia simple de búsqueda (case-insensitive, sin acentos
  /// normalizados — suficiente para el MVP).
  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase();
    return question.toLowerCase().contains(q) ||
        answer.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q);
  }

  @override
  List<Object?> get props => [id, category, question, answer];
}
