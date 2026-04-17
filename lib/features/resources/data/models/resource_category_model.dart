import 'package:equatable/equatable.dart';
import '../../domain/entities/resource_category.dart';

/// Modelo de categoría de recurso para la capa de datos
class ResourceCategoryModel extends Equatable {
  final int resourceCategoryId;
  final String name;
  final String? description;

  const ResourceCategoryModel({
    required this.resourceCategoryId,
    required this.name,
    this.description,
  });

  /// Crea una instancia desde JSON
  factory ResourceCategoryModel.fromJson(Map<String, dynamic> json) {
    return ResourceCategoryModel(
      // Backend puede devolver 'resource_category_id' o 'id'
      resourceCategoryId:
          (json['resource_category_id'] ?? json['id']) as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'resource_category_id': resourceCategoryId,
      'name': name,
      'description': description,
    };
  }

  /// Convierte el modelo a entidad de dominio
  ResourceCategory toEntity() {
    return ResourceCategory(
      resourceCategoryId: resourceCategoryId,
      name: name,
      description: description,
    );
  }

  @override
  List<Object?> get props => [resourceCategoryId, name, description];
}
