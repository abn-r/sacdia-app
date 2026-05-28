import 'package:equatable/equatable.dart';

import 'class_module_detail.dart';
import 'class_requirement.dart';

/// Clase progresiva con informacion de progreso del usuario.
///
/// Combina la informacion del catalogo de la clase con el progreso
/// personal del miembro.
class ClassWithProgress extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int clubTypeId;
  final String? imageUrl;
  final int? enrollmentId;
  final String? investitureStatus;
  final int? availableFromYearId;
  final int? availableUntilYearId;
  final int minDurationYears;
  final int maxDurationYears;

  // Progreso del usuario
  final List<ClassModuleDetail> modules;

  const ClassWithProgress({
    required this.id,
    required this.name,
    this.description,
    required this.clubTypeId,
    this.imageUrl,
    this.enrollmentId,
    this.investitureStatus,
    this.availableFromYearId,
    this.availableUntilYearId,
    this.minDurationYears = 1,
    this.maxDurationYears = 1,
    this.modules = const [],
  });

  // Computed helpers

  bool get isExpired => investitureStatus?.trim().toUpperCase() == 'EXPIRED';

  /// Total de requerimientos en todos los modulos.
  int get totalRequirements =>
      modules.fold(0, (sum, m) => sum + m.requirements.length);

  /// Requerimientos completados (validados).
  int get completedRequirements =>
      modules.fold(0, (sum, m) => sum + m.completedCount);

  /// Requerimientos enviados (esperando validacion).
  int get submittedRequirements =>
      modules.fold(0, (sum, m) => sum + m.submittedCount);

  /// Total de puntos de la clase.
  int get totalPoints => modules.fold(0, (sum, m) => sum + m.totalPoints);

  /// Puntos ganados (solo requerimientos validados).
  int get earnedPoints => modules.fold(0, (sum, m) => sum + m.earnedPoints);

  /// Porcentaje de completacion (0.0 - 1.0).
  double get completionRatio =>
      totalRequirements == 0 ? 0.0 : completedRequirements / totalRequirements;

  /// Porcentaje de completacion en porcentaje entero (0 - 100).
  int get completionPercent => (completionRatio * 100).round();

  /// Lista plana de todos los requerimientos de la clase.
  List<ClassRequirement> get allRequirements =>
      modules.expand((m) => m.requirements).toList();

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        clubTypeId,
        imageUrl,
        enrollmentId,
        investitureStatus,
        availableFromYearId,
        availableUntilYearId,
        minDurationYears,
        maxDurationYears,
        modules,
      ];
}
