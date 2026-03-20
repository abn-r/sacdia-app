import 'package:equatable/equatable.dart';
import '../../domain/entities/certification.dart';

/// Modelo de certificación para la capa de datos
class CertificationModel extends Equatable {
  final int certificationId;
  final String name;
  final String? description;
  final bool active;
  final int modulesCount;

  const CertificationModel({
    required this.certificationId,
    required this.name,
    this.description,
    required this.active,
    required this.modulesCount,
  });

  /// Crea una instancia desde JSON
  factory CertificationModel.fromJson(Map<String, dynamic> json) {
    return CertificationModel(
      certificationId: (json['certification_id'] ?? json['id']) as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      active: json['active'] as bool? ?? true,
      modulesCount: (json['modules_count'] ?? json['modulesCount'] ?? 0) as int,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'certification_id': certificationId,
      'name': name,
      'description': description,
      'active': active,
      'modules_count': modulesCount,
    };
  }

  /// Convierte el modelo a entidad de dominio
  Certification toEntity() {
    return Certification(
      certificationId: certificationId,
      name: name,
      description: description,
      active: active,
      modulesCount: modulesCount,
    );
  }

  /// Crea una copia con campos actualizados
  CertificationModel copyWith({
    int? certificationId,
    String? name,
    String? description,
    bool? active,
    int? modulesCount,
  }) {
    return CertificationModel(
      certificationId: certificationId ?? this.certificationId,
      name: name ?? this.name,
      description: description ?? this.description,
      active: active ?? this.active,
      modulesCount: modulesCount ?? this.modulesCount,
    );
  }

  @override
  List<Object?> get props => [
        certificationId,
        name,
        description,
        active,
        modulesCount,
      ];
}
