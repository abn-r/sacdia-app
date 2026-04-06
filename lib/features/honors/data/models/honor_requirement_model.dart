import 'package:equatable/equatable.dart';
import '../../domain/entities/honor_requirement.dart';

/// Modelo de requisito de especialidad para la capa de datos.
///
/// Soporta requisitos jerárquicos con [children] (sub-ítems recursivos)
/// y grupos de elección ([isChoiceGroup]).
class HonorRequirementModel extends Equatable {
  final int id;
  final int honorId;
  final int requirementNumber;
  final String text;
  final bool hasSubItems;
  final bool needsReview;
  final int? parentId;
  final String? displayLabel;
  final String? referenceText;
  final bool isChoiceGroup;
  final int? choiceMin;
  final bool requiresEvidence;
  final List<HonorRequirementModel> children;

  const HonorRequirementModel({
    required this.id,
    required this.honorId,
    required this.requirementNumber,
    required this.text,
    this.hasSubItems = false,
    this.needsReview = true,
    this.parentId,
    this.displayLabel,
    this.referenceText,
    this.isChoiceGroup = false,
    this.choiceMin,
    this.requiresEvidence = false,
    this.children = const [],
  });

  /// Crea una instancia desde JSON.
  ///
  /// Soporta tanto el campo 'text' (nuevo API) como 'requirement_text' (legado).
  /// Parsea [children] de forma recursiva si el backend incluye el array.
  factory HonorRequirementModel.fromJson(Map<String, dynamic> json) {
    // Parse children recursively
    List<HonorRequirementModel> children = const [];
    final rawChildren = json['children'];
    if (rawChildren is List) {
      children = rawChildren
          .whereType<Map<String, dynamic>>()
          .map((child) => HonorRequirementModel.fromJson(child))
          .toList();
    }

    return HonorRequirementModel(
      id: json['requirement_id'] as int,
      honorId: (json['honor_id'] as int?) ?? 0,
      requirementNumber: json['requirement_number'] as int,
      text: (json['text'] ?? json['requirement_text']) as String,
      hasSubItems: (json['has_sub_items'] as bool?) ?? false,
      needsReview: (json['needs_review'] as bool?) ?? true,
      parentId: json['parent_id'] as int?,
      displayLabel: json['display_label'] as String?,
      referenceText: json['reference_text'] as String?,
      isChoiceGroup: (json['is_choice_group'] as bool?) ?? false,
      choiceMin: json['choice_min'] as int?,
      requiresEvidence: (json['requires_evidence'] as bool?) ?? false,
      children: children,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'requirement_id': id,
      'honor_id': honorId,
      'requirement_number': requirementNumber,
      'requirement_text': text,
      'has_sub_items': hasSubItems,
      'needs_review': needsReview,
      'parent_id': parentId,
      'display_label': displayLabel,
      'reference_text': referenceText,
      'is_choice_group': isChoiceGroup,
      'choice_min': choiceMin,
      'requires_evidence': requiresEvidence,
      'children': children.map((c) => c.toJson()).toList(),
    };
  }

  /// Convierte el modelo a entidad de dominio (recursivo en [children])
  HonorRequirement toEntity() {
    return HonorRequirement(
      id: id,
      honorId: honorId,
      requirementNumber: requirementNumber,
      text: text,
      hasSubItems: hasSubItems,
      needsReview: needsReview,
      parentId: parentId,
      displayLabel: displayLabel,
      referenceText: referenceText,
      isChoiceGroup: isChoiceGroup,
      choiceMin: choiceMin,
      requiresEvidence: requiresEvidence,
      children: children.map((c) => c.toEntity()).toList(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        honorId,
        requirementNumber,
        text,
        hasSubItems,
        needsReview,
        parentId,
        displayLabel,
        referenceText,
        isChoiceGroup,
        choiceMin,
        requiresEvidence,
        children,
      ];
}
