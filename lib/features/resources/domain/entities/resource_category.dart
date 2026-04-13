import 'package:equatable/equatable.dart';

/// Entidad de categoría de recurso del dominio
class ResourceCategory extends Equatable {
  final int resourceCategoryId;
  final String name;
  final String? description;

  const ResourceCategory({
    required this.resourceCategoryId,
    required this.name,
    this.description,
  });

  @override
  List<Object?> get props => [resourceCategoryId, name, description];
}
