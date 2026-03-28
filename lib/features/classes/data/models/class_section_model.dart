import 'package:equatable/equatable.dart';
import '../../domain/entities/class_section.dart';
import '../../../../core/utils/json_helpers.dart';

/// Modelo de sección de clase para la capa de datos
class ClassSectionModel extends Equatable {
  final int id;
  final String name;
  final int moduleId;
  final bool isCompleted;

  const ClassSectionModel({
    required this.id,
    required this.name,
    required this.moduleId,
    this.isCompleted = false,
  });

  /// Crea una instancia desde JSON
  factory ClassSectionModel.fromJson(Map<String, dynamic> json) {
    return ClassSectionModel(
      id: safeInt(json['id']),
      name: safeString(json['name']),
      moduleId: safeInt(json['module_id']),
      isCompleted: safeBool(json['is_completed']),
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'module_id': moduleId,
      'is_completed': isCompleted,
    };
  }

  /// Convierte el modelo a entidad de dominio
  ClassSection toEntity() {
    return ClassSection(
      id: id,
      name: name,
      moduleId: moduleId,
      isCompleted: isCompleted,
    );
  }

  /// Crea una copia con campos actualizados
  ClassSectionModel copyWith({
    int? id,
    String? name,
    int? moduleId,
    bool? isCompleted,
  }) {
    return ClassSectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      moduleId: moduleId ?? this.moduleId,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [id, name, moduleId, isCompleted];
}
