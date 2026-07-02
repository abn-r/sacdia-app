import 'package:equatable/equatable.dart';
import '../../domain/entities/class_progress.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/track_eligibility.dart';
import '../../domain/entities/track_progress.dart';

/// Modelo de progreso de clase para la capa de datos
class ClassProgressModel extends Equatable {
  final int classId;
  final int totalSections;
  final int completedSections;
  final double percentage;
  final int? overallProgress;
  final TrackProgress basicProgress;
  final TrackProgress advancedProgress;
  final TrackProgress extraProgress;
  final TrackEligibility? investitureEligibility;
  final TrackEligibility? advancedEligibility;

  const ClassProgressModel({
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

  /// Crea una instancia desde JSON
  factory ClassProgressModel.fromJson(Map<String, dynamic> json) {
    final total = safeInt(json['total_sections']);
    final completed = safeInt(json['completed_sections']);
    final legacyPercent = (total > 0 ? (completed / total) * 100 : 0.0);
    final percentage = safeDouble(json['percentage'], legacyPercent);
    final fallbackFromOverall =
        safeDouble(json['overall_progress'], percentage);

    final resolvedPercentage = fallbackFromOverall == 0.0 && percentage == 0.0
        ? legacyPercent
        : fallbackFromOverall;

    return ClassProgressModel(
      classId: safeInt(json['class_id']),
      totalSections: total,
      completedSections: completed,
      percentage: resolvedPercentage,
      overallProgress: safeIntOrNull(json['overall_progress']),
      basicProgress: TrackProgress.fromJson(json['basic_progress']),
      advancedProgress: TrackProgress.fromJson(json['advanced_progress']),
      extraProgress: TrackProgress.fromJson(json['extra_progress']),
      investitureEligibility:
          TrackEligibility.fromJson(json['investiture_eligibility']),
      advancedEligibility:
          TrackEligibility.fromJson(json['advanced_eligibility']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'total_sections': totalSections,
      'completed_sections': completedSections,
      'overall_progress': overallProgress,
      'percentage': percentage,
      'basic_progress': basicProgress.toJson(),
      'advanced_progress': advancedProgress.toJson(),
      'extra_progress': extraProgress.toJson(),
      'investiture_eligibility': investitureEligibility?.toJson(),
      'advanced_eligibility': advancedEligibility?.toJson(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  ClassProgress toEntity() {
    return ClassProgress(
      classId: classId,
      totalSections: totalSections,
      completedSections: completedSections,
      percentage: percentage,
      overallProgress: overallProgress,
      basicProgress: basicProgress,
      advancedProgress: advancedProgress,
      extraProgress: extraProgress,
      investitureEligibility: investitureEligibility,
      advancedEligibility: advancedEligibility,
    );
  }

  /// Crea una copia con campos actualizados
  ClassProgressModel copyWith({
    int? classId,
    int? totalSections,
    int? completedSections,
    double? percentage,
    int? overallProgress,
    TrackProgress? basicProgress,
    TrackProgress? advancedProgress,
    TrackProgress? extraProgress,
    TrackEligibility? investitureEligibility,
    TrackEligibility? advancedEligibility,
  }) {
    return ClassProgressModel(
      classId: classId ?? this.classId,
      totalSections: totalSections ?? this.totalSections,
      completedSections: completedSections ?? this.completedSections,
      percentage: percentage ?? this.percentage,
      overallProgress: overallProgress ?? this.overallProgress,
      basicProgress: basicProgress ?? this.basicProgress,
      advancedProgress: advancedProgress ?? this.advancedProgress,
      extraProgress: extraProgress ?? this.extraProgress,
      investitureEligibility:
          investitureEligibility ?? this.investitureEligibility,
      advancedEligibility: advancedEligibility ?? this.advancedEligibility,
    );
  }

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
}
