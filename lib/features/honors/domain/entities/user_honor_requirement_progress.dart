import 'package:equatable/equatable.dart';

/// Entidad de progreso de requisito de especialidad por usuario del dominio.
///
/// Representa el estado de completado de un requisito individual
/// dentro de una especialidad inscripta por el usuario.
class UserHonorRequirementProgress extends Equatable {
  final int requirementId;
  final int requirementNumber;
  final String text;
  final bool completed;
  final String? notes;
  final DateTime? completedAt;

  const UserHonorRequirementProgress({
    required this.requirementId,
    required this.requirementNumber,
    required this.text,
    this.completed = false,
    this.notes,
    this.completedAt,
  });

  @override
  List<Object?> get props => [
        requirementId,
        requirementNumber,
        text,
        completed,
        notes,
        completedAt,
      ];
}
