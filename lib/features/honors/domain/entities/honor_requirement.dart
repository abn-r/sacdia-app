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
