import 'package:equatable/equatable.dart';

/// Entidad de progreso de clase del dominio
class ClassProgress extends Equatable {
  final int classId;
  final int totalSections;
  final int completedSections;
  final double percentage;

  const ClassProgress({
    required this.classId,
    required this.totalSections,
    required this.completedSections,
    required this.percentage,
  });

  @override
  List<Object?> get props => [classId, totalSections, completedSections, percentage];
}
