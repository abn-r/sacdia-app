import 'package:equatable/equatable.dart';
import '../../domain/entities/class_progress.dart';

/// Modelo de progreso de clase para la capa de datos
class ClassProgressModel extends Equatable {
  final int classId;
  final int totalSections;
  final int completedSections;
  final double percentage;

  const ClassProgressModel({
    required this.classId,
    required this.totalSections,
    required this.completedSections,
    required this.percentage,
  });

  /// Crea una instancia desde JSON
  factory ClassProgressModel.fromJson(Map<String, dynamic> json) {
    final total = json['total_sections'] as int;
    final completed = json['completed_sections'] as int;
    final percentage = total > 0 ? (completed / total) * 100 : 0.0;

    return ClassProgressModel(
      classId: json['class_id'] as int,
      totalSections: total,
      completedSections: completed,
      percentage: percentage,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'total_sections': totalSections,
      'completed_sections': completedSections,
      'percentage': percentage,
    };
  }

  /// Convierte el modelo a entidad de dominio
  ClassProgress toEntity() {
    return ClassProgress(
      classId: classId,
      totalSections: totalSections,
      completedSections: completedSections,
      percentage: percentage,
    );
  }

  /// Crea una copia con campos actualizados
  ClassProgressModel copyWith({
    int? classId,
    int? totalSections,
    int? completedSections,
    double? percentage,
  }) {
    return ClassProgressModel(
      classId: classId ?? this.classId,
      totalSections: totalSections ?? this.totalSections,
      completedSections: completedSections ?? this.completedSections,
      percentage: percentage ?? this.percentage,
    );
  }

  @override
  List<Object?> get props => [classId, totalSections, completedSections, percentage];
}
