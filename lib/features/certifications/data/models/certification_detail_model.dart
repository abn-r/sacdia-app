import 'package:equatable/equatable.dart';
import '../../domain/entities/certification_detail.dart';
import 'certification_module_model.dart';

/// Modelo de detalle de certificación para la capa de datos
class CertificationDetailModel extends Equatable {
  final int certificationId;
  final String name;
  final String? description;
  final bool active;
  final int modulesCount;
  final List<CertificationModuleModel> modules;

  const CertificationDetailModel({
    required this.certificationId,
    required this.name,
    this.description,
    required this.active,
    required this.modulesCount,
    this.modules = const [],
  });

  /// Crea una instancia desde JSON
  factory CertificationDetailModel.fromJson(Map<String, dynamic> json) {
    return CertificationDetailModel(
      certificationId: (json['certification_id'] ?? json['id']) as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      active: json['active'] as bool? ?? true,
      modulesCount: (json['modules_count'] ?? json['modulesCount'] ?? 0) as int,
      modules: (json['modules'] as List<dynamic>?)
              ?.map((m) => CertificationModuleModel.fromJson(
                  m as Map<String, dynamic>))
              .toList() ??
          [],
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
      'modules': modules.map((m) => m.toJson()).toList(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  CertificationDetail toEntity() {
    return CertificationDetail(
      certificationId: certificationId,
      name: name,
      description: description,
      active: active,
      modulesCount: modulesCount,
      modules: modules.map((m) => m.toEntity()).toList(),
    );
  }

  /// Crea una copia con campos actualizados
  CertificationDetailModel copyWith({
    int? certificationId,
    String? name,
    String? description,
    bool? active,
    int? modulesCount,
    List<CertificationModuleModel>? modules,
  }) {
    return CertificationDetailModel(
      certificationId: certificationId ?? this.certificationId,
      name: name ?? this.name,
      description: description ?? this.description,
      active: active ?? this.active,
      modulesCount: modulesCount ?? this.modulesCount,
      modules: modules ?? this.modules,
    );
  }

  @override
  List<Object?> get props => [
        certificationId,
        name,
        description,
        active,
        modulesCount,
        modules,
      ];
}
