import 'package:equatable/equatable.dart';
import '../../domain/entities/certification_section.dart';

/// Modelo de sección de módulo de certificación para la capa de datos
class CertificationSectionModel extends Equatable {
  final int sectionId;
  final String name;
  final String? description;

  const CertificationSectionModel({
    required this.sectionId,
    required this.name,
    this.description,
  });

  /// Crea una instancia desde JSON
  factory CertificationSectionModel.fromJson(Map<String, dynamic> json) {
    return CertificationSectionModel(
      sectionId: (json['section_id'] ?? json['id']) as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'section_id': sectionId,
      'name': name,
      'description': description,
    };
  }

  /// Convierte el modelo a entidad de dominio
  CertificationSection toEntity() {
    return CertificationSection(
      sectionId: sectionId,
      name: name,
      description: description,
    );
  }

  /// Crea una copia con campos actualizados
  CertificationSectionModel copyWith({
    int? sectionId,
    String? name,
    String? description,
  }) {
    return CertificationSectionModel(
      sectionId: sectionId ?? this.sectionId,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [sectionId, name, description];
}
