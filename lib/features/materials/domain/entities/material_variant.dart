import 'package:equatable/equatable.dart';

import 'material_variant_option.dart';
import 'material_variant_type.dart';

/// Variante de un producto (ej. tallas, colores disponibles).
///
/// Un producto tiene como máximo una variante en v1 (invariante de negocio).
class MaterialVariant extends Equatable {
  final String id;
  final MaterialVariantType type;
  final List<MaterialVariantOption> options;

  const MaterialVariant({
    required this.id,
    required this.type,
    required this.options,
  });

  /// Opciones con stock disponible.
  List<MaterialVariantOption> get availableOptions =>
      options.where((o) => o.hasStock).toList();

  @override
  List<Object?> get props => [id, type, options];
}
