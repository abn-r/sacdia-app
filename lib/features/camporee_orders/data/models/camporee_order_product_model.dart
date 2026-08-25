import '../../domain/entities/camporee_order_product.dart';

/// Modelo de opción de talla.
class CamporeeOrderProductOptionModel {
  final String optionId;
  final String productId;
  final String label;
  final int sortOrder;
  final bool active;

  const CamporeeOrderProductOptionModel({
    required this.optionId,
    required this.productId,
    required this.label,
    required this.sortOrder,
    required this.active,
  });

  factory CamporeeOrderProductOptionModel.fromJson(Map<String, dynamic> json) {
    return CamporeeOrderProductOptionModel(
      optionId: json['camporee_order_product_option_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      active: json['active'] != false,
    );
  }

  CamporeeOrderProductOption toEntity() => CamporeeOrderProductOption(
        optionId: optionId,
        productId: productId,
        label: label,
        sortOrder: sortOrder,
        active: active,
      );
}

/// Modelo de producto de la biblioteca territorial.
class CamporeeOrderProductModel {
  final String productId;
  final String title;
  final String? description;
  final String sizeScheme;
  final String ownerScope;
  final int? ownerDivisionId;
  final int? ownerUnionId;
  final int? ownerLocalFieldId;
  final int? clubTypeId;
  final bool active;
  final List<CamporeeOrderProductOptionModel> options;

  const CamporeeOrderProductModel({
    required this.productId,
    required this.title,
    required this.sizeScheme,
    required this.ownerScope,
    required this.active,
    this.description,
    this.ownerDivisionId,
    this.ownerUnionId,
    this.ownerLocalFieldId,
    this.clubTypeId,
    this.options = const [],
  });

  factory CamporeeOrderProductModel.fromJson(Map<String, dynamic> json) {
    return CamporeeOrderProductModel(
      productId: json['camporee_order_product_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      sizeScheme: json['size_scheme']?.toString() ?? 'NONE',
      ownerScope: json['owner_scope']?.toString() ?? 'DIVISION',
      ownerDivisionId: (json['owner_division_id'] as num?)?.toInt(),
      ownerUnionId: (json['owner_union_id'] as num?)?.toInt(),
      ownerLocalFieldId: (json['owner_local_field_id'] as num?)?.toInt(),
      clubTypeId: (json['club_type_id'] as num?)?.toInt(),
      active: json['active'] != false,
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => CamporeeOrderProductOptionModel.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
    );
  }

  CamporeeOrderProduct toEntity() => CamporeeOrderProduct(
        productId: productId,
        title: title,
        description: description,
        sizeScheme: CamporeeOrderSizeSchemeApi.fromApi(sizeScheme),
        ownerScope: CamporeeOrderOwnerScopeApi.fromApi(ownerScope),
        ownerDivisionId: ownerDivisionId,
        ownerUnionId: ownerUnionId,
        ownerLocalFieldId: ownerLocalFieldId,
        clubTypeId: clubTypeId,
        active: active,
        options: options.map((o) => o.toEntity()).toList(),
      );
}
