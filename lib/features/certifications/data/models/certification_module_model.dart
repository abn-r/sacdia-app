import 'package:equatable/equatable.dart';
import '../../domain/entities/certification_module.dart';
import 'certification_section_model.dart';

/// Modelo de módulo de certificación para la capa de datos
class CertificationModuleModel extends Equatable {
  final int moduleId;
  final String name;
  final String? description;
  final List<CertificationSectionModel> sections;

  const CertificationModuleModel({
    required this.moduleId,
    required this.name,
    this.description,
    this.sections = const [],
  });

  /// Crea una instancia desde JSON
  factory CertificationModuleModel.fromJson(Map<String, dynamic> json) {
    return CertificationModuleModel(
      moduleId: (json['module_id'] ?? json['id']) as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      sections: (json['sections'] as List<dynamic>?)
              ?.map((s) =>
                  CertificationSectionModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'module_id': moduleId,
      'name': name,
      'description': description,
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  CertificationModule toEntity() {
    return CertificationModule(
      moduleId: moduleId,
      name: name,
      description: description,
      sections: sections.map((s) => s.toEntity()).toList(),
    );
  }

  /// Crea una copia con campos actualizados
  CertificationModuleModel copyWith({
    int? moduleId,
    String? name,
    String? description,
    List<CertificationSectionModel>? sections,
  }) {
    return CertificationModuleModel(
      moduleId: moduleId ?? this.moduleId,
      name: name ?? this.name,
      description: description ?? this.description,
      sections: sections ?? this.sections,
    );
  }

  @override
  List<Object?> get props => [moduleId, name, description, sections];
}
