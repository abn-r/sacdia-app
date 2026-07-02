import 'package:equatable/equatable.dart';
import 'track_eligibility.dart';
import 'track_progress.dart';

/// Entidad de progreso de clase del dominio
class ClassProgress extends Equatable {
  final int classId;
  final int totalSections;
  final int completedSections;
  final double percentage;

  /// Porcentaje general heredado (0-100) para compatibilidad.
  final int? overallProgress;

  /// Progreso por track curricular.
  final TrackProgress basicProgress;
  final TrackProgress advancedProgress;
  final TrackProgress extraProgress;

  /// Elegibilidad global para enviar investidura.
  final TrackEligibility? investitureEligibility;

  /// Estado del track avanzado (si viene informado).
  final TrackEligibility? advancedEligibility;

  const ClassProgress({
    required this.classId,
    required this.totalSections,
    required this.completedSections,
    required this.percentage,
    this.overallProgress,
    required this.basicProgress,
    required this.advancedProgress,
    required this.extraProgress,
    this.investitureEligibility,
    this.advancedEligibility,
  });

  @override
  List<Object?> get props => [
        classId,
        totalSections,
        completedSections,
        percentage,
        overallProgress,
        basicProgress,
        advancedProgress,
        extraProgress,
        investitureEligibility,
        advancedEligibility,
      ];

  /// Compatibilidad: usa `overallProgress` si existe; si no, usa `percentage`.
  int get overallProgressOrLegacy {
    if (overallProgress != null) return overallProgress!;
    return percentage.round().clamp(0, 100);
  }

  bool get isOverallComplete => overallProgressOrLegacy >= 100;

  bool get hasTrackProgress =>
      basicProgress.percentage > 0 ||
      advancedProgress.percentage > 0 ||
      extraProgress.percentage > 0;
}
