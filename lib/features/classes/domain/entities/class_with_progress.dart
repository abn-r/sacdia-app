import 'package:equatable/equatable.dart';

import 'class_module_detail.dart';
import 'class_requirement.dart';
import 'requirement_track.dart';
import 'track_eligibility.dart';
import 'track_progress.dart';

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

  /// Porcentaje global legacy de enrollamiento.
  final int? overallProgress;

  /// Progreso separado por track curricular (legacy-safe).
  final TrackProgress? basicProgress;
  final TrackProgress? advancedProgress;
  final TrackProgress? extraProgress;

  /// Elegibilidad de investidura y del tramo avanzado.
  final TrackEligibility? investitureEligibility;
  final TrackEligibility? advancedEligibility;

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
    this.overallProgress,
    this.basicProgress,
    this.advancedProgress,
    this.extraProgress,
    this.investitureEligibility,
    this.advancedEligibility,
    this.modules = const [],
  });

  // Computed helpers

  bool get isExpired => investitureStatus?.trim().toUpperCase() == 'EXPIRED';

  /// Tiene información de `advanced_eligibility` habilitada.
  bool get hasAdvancedEligibility => advancedEligibility?.isEnabled == true;

  /// Hay datos explícitos por track para mostrar progreso por carrera.
  bool get hasTrackProgressData =>
      basicProgress != null ||
      advancedProgress != null ||
      extraProgress != null;

  /// Si hay algún requerimiento con track explícito en el curso.
  bool get hasTrackRequirementData =>
      modules.expand((m) => m.requirements).any((r) {
        return r.requirementTrack != null;
      });

  /// Si el curso trae datos de track para mostrar en UI.
  bool get hasTrackData => hasTrackProgressData || hasTrackRequirementData;

  /// Si el curso tiene sección avanzada explícita para mostrarla separada.
  bool get hasAdvancedTrackData =>
      hasAdvancedEligibility ||
      (advancedProgress != null &&
          ((advancedProgress!.total ?? 0) > 0 ||
              (advancedProgress!.completed ?? 0) > 0 ||
              advancedProgress!.percentage > 0)) ||
      allRequirements.any(
        (r) => r.requirementTrack == RequirementTrack.advanced,
      );

  /// Requerimientos de clase (legacy).
  int get totalRequirements =>
      modules.fold(0, (sum, m) => sum + m.requirements.length);

  /// Requerimientos completados (legacy).
  int get completedRequirements =>
      modules.fold(0, (sum, m) => sum + m.completedCount);

  /// Requerimientos enviados (legacy).
  int get submittedRequirements =>
      modules.fold(0, (sum, m) => sum + m.submittedCount);

  /// Requerimientos requeridos para investidura.
  int get totalRequirementsForInvestiture => modules.fold(
        0,
        (sum, m) =>
            sum +
            m.requirements.where((r) {
              if (hasAdvancedEligibility &&
                  r.requirementTrack == RequirementTrack.advanced) {
                return false;
              }

              if (r.requirementTrack == RequirementTrack.advanced &&
                  r.requiredForInvestiture == false) {
                return false;
              }

              return r.requiredForInvestiture != false;
            }).length,
      );

  /// Requerimientos validados para investidura.
  int get completedRequirementsForInvestiture => modules.fold(
        0,
        (sum, m) =>
            sum +
            m.requirements.where((r) {
              if (hasAdvancedEligibility &&
                  r.requirementTrack == RequirementTrack.advanced) {
                return false;
              }

              if (r.requirementTrack == RequirementTrack.advanced &&
                  r.requiredForInvestiture == false) {
                return false;
              }

              return r.requiredForInvestiture != false &&
                  r.status == RequirementStatus.validado;
            }).length,
      );

  /// Total de puntos de la clase.
  int get totalPoints => modules.fold(0, (sum, m) => sum + m.totalPoints);

  /// Puntos ganados (solo requerimientos validados).
  int get earnedPoints => modules.fold(0, (sum, m) => sum + m.earnedPoints);

  int get _legacyCompletionPercent {
    if (totalRequirements == 0) return 0;
    return ((completedRequirements / totalRequirements) * 100)
        .round()
        .clamp(0, 100)
        .toInt();
  }

  /// Porcentaje de investidura: desarrollo de clase + extras obligatorios.
  int get investitureProgressPercent {
    if (overallProgress != null) {
      return overallProgress!.clamp(0, 100).toInt();
    }

    if (totalRequirementsForInvestiture == 0) {
      return _legacyCompletionPercent;
    }

    return ((completedRequirementsForInvestiture /
                totalRequirementsForInvestiture) *
            100)
        .round()
        .clamp(0, 100)
        .toInt();
  }

  /// Ratio de investidura (0.0 - 1.0).
  double get investitureProgressRatio => investitureProgressPercent / 100.0;

  /// Compatibility: el progreso global representa investidura.
  int get overallProgressOrLegacy => investitureProgressPercent;

  /// Porcentaje de completacion (0.0 - 1.0) usado por vistas resumen.
  double get completionRatio => investitureProgressRatio;

  /// Porcentaje de completacion en porcentaje entero (0 - 100) legacy.
  int get completionPercent => investitureProgressPercent;

  /// Lista plana de todos los requerimientos de la clase.
  List<ClassRequirement> get allRequirements =>
      modules.expand((m) => m.requirements).toList();

  /// Estado visual recomendado para la tarjeta de investidura.
  bool get isInvestitureEligibleByTrackOrLegacy {
    final explicit = investitureEligibility?.eligible;
    if (explicit != null) {
      return explicit;
    }

    if (overallProgress != null) {
      return overallProgress == 100;
    }

    if (totalRequirementsForInvestiture == 0) return false;
    return completedRequirementsForInvestiture ==
        totalRequirementsForInvestiture;
  }

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
        overallProgress,
        basicProgress,
        advancedProgress,
        extraProgress,
        investitureEligibility,
        advancedEligibility,
        modules,
      ];
}
