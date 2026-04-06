import 'package:equatable/equatable.dart';

/// Entidad de requisito de especialidad del dominio.
///
/// Representa un requisito individual del catálogo de especialidades.
/// Los requisitos son parte del catálogo global — no son por usuario.
/// Soporta jerarquía: un requisito puede tener [children] (sub-ítems)
/// y puede pertenecer a un grupo de elección ([isChoiceGroup]).
class HonorRequirement extends Equatable {
  final int id;
  final int honorId;
  final int requirementNumber;
  final String text;
  final bool hasSubItems;
  final bool needsReview;

  /// ID del requisito padre, presente cuando este es un sub-ítem.
  final int? parentId;

  /// Etiqueta de display jerárquica, ej. "1", "a", "i".
  final String? displayLabel;

  /// Texto de referencia bíblica o doctrinal asociado al requisito.
  final String? referenceText;

  /// Indica si este requisito es un grupo de elección (el club elige [choiceMin] de sus hijos).
  final bool isChoiceGroup;

  /// Cantidad mínima de sub-ítems a completar cuando [isChoiceGroup] es true.
  final int? choiceMin;

  /// Indica si este requisito exige evidencia adjunta para marcarse como completado.
  final bool requiresEvidence;

  /// Sub-requisitos hijos, presentes cuando [hasSubItems] es true.
  final List<HonorRequirement> children;

  const HonorRequirement({
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

  HonorRequirement copyWith({
    int? id,
    int? honorId,
    int? requirementNumber,
    String? text,
    bool? hasSubItems,
    bool? needsReview,
    int? parentId,
    String? displayLabel,
    String? referenceText,
    bool? isChoiceGroup,
    int? choiceMin,
    bool? requiresEvidence,
    List<HonorRequirement>? children,
  }) {
    return HonorRequirement(
      id: id ?? this.id,
      honorId: honorId ?? this.honorId,
      requirementNumber: requirementNumber ?? this.requirementNumber,
      text: text ?? this.text,
      hasSubItems: hasSubItems ?? this.hasSubItems,
      needsReview: needsReview ?? this.needsReview,
      parentId: parentId ?? this.parentId,
      displayLabel: displayLabel ?? this.displayLabel,
      referenceText: referenceText ?? this.referenceText,
      isChoiceGroup: isChoiceGroup ?? this.isChoiceGroup,
      choiceMin: choiceMin ?? this.choiceMin,
      requiresEvidence: requiresEvidence ?? this.requiresEvidence,
      children: children ?? this.children,
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
