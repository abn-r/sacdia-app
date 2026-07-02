import 'package:equatable/equatable.dart';
import 'requirement_track.dart';

/// Entidad de sección de clase del dominio
class ClassSection extends Equatable {
  final int id;
  final String name;
  final int moduleId;
  final bool isCompleted;

  /// Track curricular al que pertenece la sección.
  final RequirementTrack? requirementTrack;

  /// Indica si esta sección es obligatoria para iniciar investidura.
  final bool? requiredForInvestiture;

  /// Orden de despliegue por definición catalogada.
  final int? displayOrder;

  const ClassSection({
    required this.id,
    required this.name,
    required this.moduleId,
    this.isCompleted = false,
    this.requirementTrack,
    this.requiredForInvestiture,
    this.displayOrder,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        moduleId,
        isCompleted,
        requirementTrack,
        requiredForInvestiture,
        displayOrder,
      ];
}
