import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/scoring_category.dart';

/// Modelo de datos para una categoría de puntuación.
///
/// Respuesta esperada del backend (GET /local-fields/:fieldId/scoring-categories):
/// ```json
/// {
///   "scoring_category_id": 5,
///   "name": "Biblia",
///   "max_points": 10,
///   "origin_level": "LOCAL_FIELD",
///   "origin_id": 3,
///   "active": true,
///   "readonly": false
/// }
/// ```
class ScoringCategoryModel extends ScoringCategory {
  const ScoringCategoryModel({
    required super.scoringCategoryId,
    required super.name,
    required super.maxPoints,
    required super.originLevel,
    required super.originId,
    super.active,
    super.readonly,
  });

  factory ScoringCategoryModel.fromJson(Map<String, dynamic> json) {
    return ScoringCategoryModel(
      scoringCategoryId: parseInt(json['scoring_category_id']) ?? 0,
      name: json['name']?.toString() ?? '',
      maxPoints: parseInt(json['max_points']) ?? 0,
      originLevel: json['origin_level']?.toString() ?? 'LOCAL_FIELD',
      originId: parseInt(json['origin_id']) ?? 0,
      active: json['active'] as bool? ?? true,
      readonly: json['readonly'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'scoring_category_id': scoringCategoryId,
        'name': name,
        'max_points': maxPoints,
        'origin_level': originLevel,
        'origin_id': originId,
        'active': active,
        'readonly': readonly,
      };

  ScoringCategory toEntity() => ScoringCategory(
        scoringCategoryId: scoringCategoryId,
        name: name,
        maxPoints: maxPoints,
        originLevel: originLevel,
        originId: originId,
        active: active,
        readonly: readonly,
      );

}
