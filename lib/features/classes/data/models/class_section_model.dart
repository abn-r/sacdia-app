import 'package:equatable/equatable.dart';
import '../../domain/entities/class_section.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/requirement_track.dart';

/// Modelo de sección de clase para la capa de datos
class ClassSectionModel extends Equatable {
  final int id;
  final String name;
  final int moduleId;
  final bool isCompleted;
  final RequirementTrack? requirementTrack;
  final bool? requiredForInvestiture;
  final int? displayOrder;

  const ClassSectionModel({
    required this.id,
    required this.name,
    required this.moduleId,
    this.isCompleted = false,
    this.requirementTrack,
    this.requiredForInvestiture,
    this.displayOrder,
  });

  /// Crea una instancia desde JSON
  factory ClassSectionModel.fromJson(Map<String, dynamic> json) {
    return ClassSectionModel(
      id: safeInt(json['id'] ?? json['section_id']),
      name: safeString(json['name'] ?? json['section_name']),
      moduleId: safeInt(json['module_id'] ?? json['moduleId']),
      isCompleted: safeBool(json['is_completed'] ?? json['completed']),
      requirementTrack: RequirementTrackMeta.fromValue(
          json['requirement_track'] ?? json['requirementTrack']),
      requiredForInvestiture: json['required_for_investiture'] as bool? ??
          json['requiredForInvestiture'] as bool?,
      displayOrder: safeIntOrNull(json['display_order']) ??
          safeIntOrNull(json['displayOrder']),
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'module_id': moduleId,
      'is_completed': isCompleted,
      'requirement_track': requirementTrack?.name.toUpperCase(),
      'required_for_investiture': requiredForInvestiture,
      'display_order': displayOrder,
    };
  }

  /// Convierte el modelo a entidad de dominio
  ClassSection toEntity() {
    return ClassSection(
      id: id,
      name: name,
      moduleId: moduleId,
      isCompleted: isCompleted,
      requirementTrack: requirementTrack,
      requiredForInvestiture: requiredForInvestiture,
      displayOrder: displayOrder,
    );
  }

  /// Crea una copia con campos actualizados
  ClassSectionModel copyWith({
    int? id,
    String? name,
    int? moduleId,
    bool? isCompleted,
    RequirementTrack? requirementTrack,
    bool? requiredForInvestiture,
    int? displayOrder,
  }) {
    return ClassSectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      moduleId: moduleId ?? this.moduleId,
      isCompleted: isCompleted ?? this.isCompleted,
      requirementTrack: requirementTrack ?? this.requirementTrack,
      requiredForInvestiture:
          requiredForInvestiture ?? this.requiredForInvestiture,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        moduleId,
        isCompleted,
        requirementTrack,
        requiredForInvestiture,
        displayOrder,
      ];
}
