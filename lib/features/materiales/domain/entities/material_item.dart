import 'package:equatable/equatable.dart';

import 'material_category.dart';
import 'material_programa.dart';
import 'material_variant.dart';

/// Producto del catálogo de materiales.
class MaterialItem extends Equatable {
  final String id;
  final String sku;
  final String title;
  final String? description;
  final MaterialCategory category;
  final MaterialPrograma programa;

  /// Precio en centavos (MXN). Nunca float.
  final int priceCentavos;

  /// Stock total del producto. Si tiene variantes, es la suma de todos los
  /// stocks de opciones. Si no tiene variantes, es el stock directo.
  final int stock;

  final bool active;

  /// Variante del producto (máximo una en v1).
  /// Null si el producto no tiene variantes.
  final MaterialVariant? variant;

  const MaterialItem({
    required this.id,
    required this.sku,
    required this.title,
    this.description,
    required this.category,
    required this.programa,
    required this.priceCentavos,
    required this.stock,
    required this.active,
    this.variant,
  });

  bool get hasVariants => variant != null;
  bool get hasStock => stock > 0;

  @override
  List<Object?> get props => [
        id,
        sku,
        title,
        description,
        category,
        programa,
        priceCentavos,
        stock,
        active,
        variant
      ];
}
