import 'package:equatable/equatable.dart';

/// Opción individual dentro de una variante de producto (ej. talla "M", color "azul").
class MaterialVariantOption extends Equatable {
  final String id;
  final String label;
  final int stock;

  const MaterialVariantOption({
    required this.id,
    required this.label,
    required this.stock,
  });

  bool get hasStock => stock > 0;

  @override
  List<Object?> get props => [id, label, stock];
}
