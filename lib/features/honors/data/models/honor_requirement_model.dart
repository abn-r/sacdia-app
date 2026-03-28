import 'package:equatable/equatable.dart';
import '../../domain/entities/honor_requirement.dart';

/// Modelo de requisito de especialidad para la capa de datos
class HonorRequirementModel extends Equatable {
  final int id;
  final int honorId;
  final int requirementNumber;
  final String text;
  final bool hasSubItems;
  final bool needsReview;

  const HonorRequirementModel({
    required this.id,
    required this.honorId,
    required this.requirementNumber,
    required this.text,
    this.hasSubItems = false,
    this.needsReview = true,
  });

  /// Crea una instancia desde JSON.
  ///
  /// Soporta tanto el campo 'text' (nuevo API) como 'requirement_text' (legado).
  factory HonorRequirementModel.fromJson(Map<String, dynamic> json) {
    return HonorRequirementModel(
      id: json['requirement_id'] as int,
      honorId: json['honor_id'] as int,
      requirementNumber: json['requirement_number'] as int,
      text: (json['text'] ?? json['requirement_text']) as String,
      hasSubItems: (json['has_sub_items'] as bool?) ?? false,
      needsReview: (json['needs_review'] as bool?) ?? true,
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
    };
  }

  /// Convierte el modelo a entidad de dominio
  HonorRequirement toEntity() {
    return HonorRequirement(
      id: id,
      honorId: honorId,
      requirementNumber: requirementNumber,
      text: text,
      hasSubItems: hasSubItems,
      needsReview: needsReview,
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
      ];
}
