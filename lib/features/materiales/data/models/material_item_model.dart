import '../../domain/entities/material_item.dart';
import 'material_category_model.dart';
import 'material_programa_model.dart';
import 'material_variant_model.dart';

/// Modelo de datos para [MaterialItem].
///
/// Mapea la respuesta JSON del endpoint GET /materiales/catalogo y GET /materiales/catalogo/:id.
class MaterialItemModel extends MaterialItem {
  const MaterialItemModel({
    required super.id,
    required super.sku,
    required super.title,
    super.description,
    required super.category,
    required super.programa,
    required super.priceCentavos,
    required super.stock,
    required super.active,
    super.variant,
  });

  factory MaterialItemModel.fromJson(Map<String, dynamic> json) {
    final catJson = json['cat'] as Map<String, dynamic>?;
    final programaJson = json['programa'] as Map<String, dynamic>?;

    // variants?: el backend envía el objeto variante directamente (no array)
    // cuando el producto tiene variantes (v1: máximo una).
    final variantJson = json['variants'] as Map<String, dynamic>?;

    return MaterialItemModel(
      id: (json['id'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      category: catJson != null
          ? MaterialCategoryModel.fromJson(catJson)
          : const MaterialCategoryModel(
              id: '',
              slug: '',
              label: '',
              sortOrder: 0,
            ),
      programa: programaJson != null
          ? MaterialProgramaModel.fromJson(programaJson)
          : const MaterialProgramaModel(id: 0, label: ''),
      priceCentavos:
          (json['price_centavos'] ?? json['priceCentavos'] ?? 0) as int,
      stock: (json['stock'] ?? 0) as int,
      active: (json['active'] ?? true) as bool,
      variant: variantJson != null
          ? MaterialVariantModel.fromJson(variantJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final cat = category;
    final prog = programa;
    return {
      'id': id,
      'sku': sku,
      'title': title,
      if (description != null) 'description': description,
      'cat': {
        'id': cat.id,
        'slug': cat.slug,
        'label': cat.label,
      },
      'programa': {
        'id': prog.id,
        'label': prog.label,
      },
      'price_centavos': priceCentavos,
      'stock': stock,
      'active': active,
      if (variant != null)
        'variants': MaterialVariantModel(
          id: variant!.id,
          type: variant!.type,
          options: variant!.options,
        ).toJson(),
    };
  }

  MaterialItem toEntity() => MaterialItem(
        id: id,
        sku: sku,
        title: title,
        description: description,
        category: category,
        programa: programa,
        priceCentavos: priceCentavos,
        stock: stock,
        active: active,
        variant: variant,
      );
}
