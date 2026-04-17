import 'package:equatable/equatable.dart';

import 'class_requirement.dart';

/// Modulo con requerimientos completos de una clase progresiva.
///
/// Extiende el concepto de [ClassModule] con el detalle de requerimientos
/// que incluyen estado, evidencias y trazabilidad.
class ClassModuleDetail extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int classId;

  final List<ClassRequirement> requirements;

  const ClassModuleDetail({
    required this.id,
    required this.name,
    this.description,
    required this.classId,
    this.requirements = const [],
  });

  // Computed helpers

  /// Total de puntos del modulo.
  int get totalPoints =>
      requirements.fold(0, (sum, r) => sum + r.pointValue);

  /// Puntos ganados en el modulo (solo requerimientos validados).
  int get earnedPoints =>
      requirements.fold(0, (sum, r) => sum + r.earnedPoints);

  /// Numero de requerimientos completados (validados).
  int get completedCount =>
      requirements.where((r) => r.status == RequirementStatus.validado).length;

  /// Numero de requerimientos enviados (esperando validacion).
  int get submittedCount =>
      requirements.where((r) => r.status == RequirementStatus.enviado).length;

  /// Progreso del modulo (0.0 - 1.0).
  double get completionRatio => requirements.isEmpty
      ? 0.0
      : completedCount / requirements.length;

  /// Devuelve una copia del modulo con una lista de requerimientos diferente.
  /// Util para filtrado de busqueda sin mutar el original.
  ClassModuleDetail copyWithRequirements(List<ClassRequirement> filtered) =>
      ClassModuleDetail(
        id: id,
        name: name,
        description: description,
        classId: classId,
        requirements: filtered,
      );

  @override
  List<Object?> get props => [id, name, description, classId, requirements];
}
