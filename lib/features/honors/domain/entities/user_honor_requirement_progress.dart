import 'package:equatable/equatable.dart';

/// Entidad de progreso de requisito de especialidad por usuario del dominio.
///
/// Representa el estado de completado de un requisito individual
/// dentro de una especialidad inscrita por el usuario.
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

  UserHonorRequirementProgress copyWith({
    int? requirementId,
    int? requirementNumber,
    String? text,
    bool? completed,
    String? notes,
    DateTime? completedAt,
  }) {
    return UserHonorRequirementProgress(
      requirementId: requirementId ?? this.requirementId,
      requirementNumber: requirementNumber ?? this.requirementNumber,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
    );
  }

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
