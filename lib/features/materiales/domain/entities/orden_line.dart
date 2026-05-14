import 'package:equatable/equatable.dart';

import 'material_disponibilidad.dart';

/// Snapshot mínimo de producto embebido en una línea de orden.
class OrdenLineProduct extends Equatable {
  final String id;
  final String sku;
  final String title;

  const OrdenLineProduct({
    required this.id,
    required this.sku,
    required this.title,
  });

  @override
  List<Object?> get props => [id, sku, title];
}

/// Línea de una orden de materiales.
///
/// Todos los montos en centavos (MXN).
class OrdenLine extends Equatable {
  final String id;
  final String productId;
  final String? variantOptionId;
  final int qty;

  /// Precio snapshot al momento de crear la orden (centavos).
  final int priceCentavos;

  final MaterialDisponibilidad disponibilidad;

  /// Cantidad disponible confirmada por campo. Null hasta que campo lo revise.
  final int? qtyDisponible;

  /// Total de la línea en centavos (qty_disponible × price_centavos).
  final int lineTotalCentavos;

  /// Snapshot mínimo del producto para mostrar en UI sin refetch.
  final OrdenLineProduct product;

  const OrdenLine({
    required this.id,
    required this.productId,
    this.variantOptionId,
    required this.qty,
    required this.priceCentavos,
    required this.disponibilidad,
    this.qtyDisponible,
    required this.lineTotalCentavos,
    required this.product,
  });

  @override
  List<Object?> get props => [
        id,
        productId,
        variantOptionId,
        qty,
        priceCentavos,
        disponibilidad,
        qtyDisponible,
        lineTotalCentavos,
        product,
      ];
}
