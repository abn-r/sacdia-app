import 'package:equatable/equatable.dart';
import '../../domain/entities/user_honor_requirement_progress.dart';

/// Modelo de progreso de requisito de especialidad por usuario para la capa de datos
class UserHonorRequirementProgressModel extends Equatable {
  final int requirementId;
  final int requirementNumber;
  final String text;
  final bool completed;
  final bool hasSubItems;
  final String? notes;
  final DateTime? completedAt;

  const UserHonorRequirementProgressModel({
    required this.requirementId,
    required this.requirementNumber,
    required this.text,
    this.completed = false,
    this.hasSubItems = false,
    this.notes,
    this.completedAt,
  });

  /// Crea una instancia desde JSON
  factory UserHonorRequirementProgressModel.fromJson(
      Map<String, dynamic> json) {
    // Parse nullable completed_at ISO datetime string
    DateTime? completedAt;
    final rawCompletedAt = json['completed_at'] as String?;
    if (rawCompletedAt != null) {
      completedAt = DateTime.tryParse(rawCompletedAt);
    }

    return UserHonorRequirementProgressModel(
      requirementId: json['requirement_id'] as int,
      requirementNumber: json['requirement_number'] as int,
      text: (json['requirement_text'] ?? json['text']) as String,
      completed: (json['completed'] as bool?) ?? false,
      hasSubItems: (json['has_sub_items'] as bool?) ?? false,
      notes: json['notes'] as String?,
      completedAt: completedAt,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'requirement_id': requirementId,
      'requirement_number': requirementNumber,
      'requirement_text': text,
      'completed': completed,
      'has_sub_items': hasSubItems,
      'notes': notes,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  /// Crea una copia del modelo con campos opcionales sobreescritos
  UserHonorRequirementProgressModel copyWith({
    int? requirementId,
    int? requirementNumber,
    String? text,
    bool? completed,
    bool? hasSubItems,
    String? notes,
    DateTime? completedAt,
  }) {
    return UserHonorRequirementProgressModel(
      requirementId: requirementId ?? this.requirementId,
      requirementNumber: requirementNumber ?? this.requirementNumber,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      hasSubItems: hasSubItems ?? this.hasSubItems,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Convierte el modelo a entidad de dominio
  UserHonorRequirementProgress toEntity() {
    return UserHonorRequirementProgress(
      requirementId: requirementId,
      requirementNumber: requirementNumber,
      text: text,
      completed: completed,
      hasSubItems: hasSubItems,
      notes: notes,
      completedAt: completedAt,
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
      ];
}
