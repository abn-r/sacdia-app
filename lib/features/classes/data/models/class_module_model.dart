import 'package:equatable/equatable.dart';
import '../../domain/entities/class_module.dart';
import 'class_section_model.dart';
import '../../../../core/utils/json_helpers.dart';

/// Modelo de módulo de clase para la capa de datos
class ClassModuleModel extends Equatable {
  final int id;
  final String name;
  final int classId;
  final List<ClassSectionModel> sections;

  const ClassModuleModel({
    required this.id,
    required this.name,
    required this.classId,
    required this.sections,
  });

  /// Crea una instancia desde JSON
  factory ClassModuleModel.fromJson(Map<String, dynamic> json) {
    return ClassModuleModel(
      id: safeInt(json['id']),
      name: safeString(json['name']),
      classId: safeInt(json['class_id']),
      sections: (json['sections'] as List<dynamic>?)
              ?.map((section) => ClassSectionModel.fromJson(section as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'class_id': classId,
      'sections': sections.map((section) => section.toJson()).toList(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  ClassModule toEntity() {
    return ClassModule(
      id: id,
      name: name,
      classId: classId,
      sections: sections.map((section) => section.toEntity()).toList(),
    );
  }

  /// Crea una copia con campos actualizados
  ClassModuleModel copyWith({
    int? id,
    String? name,
    int? classId,
    List<ClassSectionModel>? sections,
  }) {
    return ClassModuleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      classId: classId ?? this.classId,
      sections: sections ?? this.sections,
    );
  }

  @override
  List<Object?> get props => [id, name, classId, sections];
}
