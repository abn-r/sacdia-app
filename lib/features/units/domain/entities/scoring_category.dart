/// Categoría de puntuación configurable en la jerarquía organizacional.
///
/// Las categorías se heredan de forma jerárquica:
/// División → Unión → Campo Local.
///
/// Una categoría heredada tiene [readonly] en true, lo que significa que
/// el nivel actual no puede modificarla ni eliminarla.
class ScoringCategory {
  final int scoringCategoryId;
  final String name;
  final int maxPoints;

  /// Nivel organizacional que creó esta categoría.
  /// Posibles valores: "DIVISION", "UNION", "LOCAL_FIELD"
  final String originLevel;

  /// ID del objeto organizacional (división, unión o campo local) que la creó.
  final int originId;

  final bool active;

  /// Si es true, el nivel actual no puede editar ni eliminar esta categoría
  /// (fue heredada de un nivel superior).
  final bool readonly;

  const ScoringCategory({
    required this.scoringCategoryId,
    required this.name,
    required this.maxPoints,
    required this.originLevel,
    required this.originId,
    this.active = true,
    this.readonly = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoringCategory &&
          other.scoringCategoryId == scoringCategoryId;

  @override
  int get hashCode => scoringCategoryId.hashCode;
}
