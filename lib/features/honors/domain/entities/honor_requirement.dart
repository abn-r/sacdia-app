import 'package:equatable/equatable.dart';

/// Entidad de requisito de especialidad del dominio.
///
/// Representa un requisito individual del catálogo de especialidades.
/// Los requisitos son parte del catálogo global — no son por usuario.
class HonorRequirement extends Equatable {
  final int id;
  final int honorId;
  final int requirementNumber;
  final String text;
  final bool hasSubItems;
  final bool needsReview;

  const HonorRequirement({
    required this.id,
    required this.honorId,
    required this.requirementNumber,
    required this.text,
    this.hasSubItems = false,
    this.needsReview = true,
  });

  HonorRequirement copyWith({
    int? id,
    int? honorId,
    int? requirementNumber,
    String? text,
    bool? hasSubItems,
    bool? needsReview,
  }) {
    return HonorRequirement(
      id: id ?? this.id,
      honorId: honorId ?? this.honorId,
      requirementNumber: requirementNumber ?? this.requirementNumber,
      text: text ?? this.text,
      hasSubItems: hasSubItems ?? this.hasSubItems,
      needsReview: needsReview ?? this.needsReview,
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
