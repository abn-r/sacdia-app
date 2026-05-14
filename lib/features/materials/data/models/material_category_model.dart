import '../../domain/entities/material_category.dart';

/// Modelo de datos para [MaterialCategory].
///
/// Mapea la respuesta JSON del endpoint GET /materiales/catalogo/categorias.
class MaterialCategoryModel extends MaterialCategory {
  const MaterialCategoryModel({
    required super.id,
    required super.slug,
    required super.label,
    super.icon,
    required super.sortOrder,
  });

  factory MaterialCategoryModel.fromJson(Map<String, dynamic> json) {
    return MaterialCategoryModel(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      icon: json['icon']?.toString(),
      sortOrder: (json['sort_order'] ?? json['sortOrder'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'label': label,
      if (icon != null) 'icon': icon,
      'sort_order': sortOrder,
    };
  }

  MaterialCategory toEntity() => MaterialCategory(
        id: id,
        slug: slug,
        label: label,
        icon: icon,
        sortOrder: sortOrder,
      );
}
