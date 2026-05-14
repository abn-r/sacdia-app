import '../../domain/entities/material_variant_option.dart';

/// Modelo de datos para [MaterialVariantOption].
class MaterialVariantOptionModel extends MaterialVariantOption {
  const MaterialVariantOptionModel({
    required super.id,
    required super.label,
    required super.stock,
  });

  factory MaterialVariantOptionModel.fromJson(Map<String, dynamic> json) {
    return MaterialVariantOptionModel(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      stock: (json['stock'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'stock': stock,
    };
  }

  MaterialVariantOption toEntity() => MaterialVariantOption(
        id: id,
        label: label,
        stock: stock,
      );
}
