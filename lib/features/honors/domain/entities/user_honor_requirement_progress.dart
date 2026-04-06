import 'package:equatable/equatable.dart';
import 'requirement_evidence.dart';

/// Entidad de progreso de requisito de especialidad por usuario del dominio.
///
/// Representa el estado de completado de un requisito individual
/// dentro de una especialidad inscrita por el usuario.
/// Incluye soporte para respuesta textual y evidencias adjuntas.
class UserHonorRequirementProgress extends Equatable {
  final int requirementId;
  final int requirementNumber;
  final String text;
  final bool completed;
  final bool hasSubItems;
  final String? notes;
  final DateTime? completedAt;

  /// Respuesta escrita del usuario cuando el requisito lo solicita.
  final String? textResponse;

  /// Evidencias adjuntas (imágenes, archivos, enlaces) para este requisito.
  final List<RequirementEvidence> evidences;

  const UserHonorRequirementProgress({
    required this.requirementId,
    required this.requirementNumber,
    required this.text,
    this.completed = false,
    this.hasSubItems = false,
    this.notes,
    this.completedAt,
    this.textResponse,
    this.evidences = const [],
  });

  UserHonorRequirementProgress copyWith({
    int? requirementId,
    int? requirementNumber,
    String? text,
    bool? completed,
    bool? hasSubItems,
    String? notes,
    DateTime? completedAt,
    String? textResponse,
    List<RequirementEvidence>? evidences,
  }) {
    return UserHonorRequirementProgress(
      requirementId: requirementId ?? this.requirementId,
      requirementNumber: requirementNumber ?? this.requirementNumber,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      hasSubItems: hasSubItems ?? this.hasSubItems,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
      textResponse: textResponse ?? this.textResponse,
      evidences: evidences ?? this.evidences,
    );
  }

  @override
  List<Object?> get props => [
        requirementId,
        requirementNumber,
        text,
        completed,
        hasSubItems,
        notes,
        completedAt,
        textResponse,
        evidences,
      ];
}
