import '../../domain/entities/material_variant.dart';
import '../../domain/entities/material_variant_type.dart';
import 'material_variant_option_model.dart';

/// Modelo de datos para [MaterialVariant].
class MaterialVariantModel extends MaterialVariant {
  const MaterialVariantModel({
    required super.id,
    required super.type,
    required super.options,
  });

  factory MaterialVariantModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return MaterialVariantModel(
      id: (json['id'] ?? '').toString(),
      type: MaterialVariantTypeX.fromString(
        (json['type'] ?? '').toString(),
      ),
      options: rawOptions
          .map((o) =>
              MaterialVariantOptionModel.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toApiString(),
      'options': options
          .map((o) => MaterialVariantOptionModel(
                id: o.id,
                label: o.label,
                stock: o.stock,
              ).toJson())
          .toList(),
    };
  }

  MaterialVariant toEntity() => MaterialVariant(
        id: id,
        type: type,
        options: options,
      );
}
