import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/material_item.dart';
import '../../domain/entities/material_variant_option.dart';

/// Línea del carrito en memoria.
class CartLine extends Equatable {
  final String productId;
  final String? variantOptionId;
  final int qty;

  /// Precio snapshot en centavos tomado al momento de agregar al carrito.
  final int priceSnapshotCentavos;

  final String productTitle;
  final String productSku;

  /// Etiqueta de la opción de variante, si aplica.
  final String? variantLabel;

  const CartLine({
    required this.productId,
    this.variantOptionId,
    required this.qty,
    required this.priceSnapshotCentavos,
    required this.productTitle,
    required this.productSku,
    this.variantLabel,
  });

  /// Total de esta línea en centavos.
  int get lineTotalCentavos => priceSnapshotCentavos * qty;

  CartLine copyWith({int? qty}) {
    return CartLine(
      productId: productId,
      variantOptionId: variantOptionId,
      qty: qty ?? this.qty,
      priceSnapshotCentavos: priceSnapshotCentavos,
      productTitle: productTitle,
      productSku: productSku,
      variantLabel: variantLabel,
    );
  }

  @override
  List<Object?> get props => [
        productId,
        variantOptionId,
        qty,
        priceSnapshotCentavos,
        productTitle,
        productSku,
        variantLabel,
      ];
}

/// Estado del carrito de compras (en memoria, sin persistencia en v1).
class CartState extends Equatable {
  final List<CartLine> lines;

  const CartState({this.lines = const []});

  /// Total de unidades en el carrito.
  int get itemCount => lines.fold(0, (acc, l) => acc + l.qty);

  /// Subtotal en centavos.
  int get subtotalCentavos =>
      lines.fold(0, (acc, l) => acc + l.lineTotalCentavos);

  @override
  List<Object?> get props => [lines];
}

/// Gestiona el estado del carrito de materiales.
///
/// v1: en memoria solamente. Sin persistencia local.
class CartNotifier extends AutoDisposeNotifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Agrega un producto al carrito.
  ///
  /// Si ya existe una línea con el mismo [productId] y [variantOptionId],
  /// incrementa la cantidad.
  void addLine(
    MaterialItem item, {
    MaterialVariantOption? variantOption,
    int qty = 1,
  }) {
    assert(qty > 0, 'qty must be positive');
    final existing = _findLine(item.id, variantOption?.id);
    if (existing != null) {
      _updateQty(item.id, variantOption?.id, existing.qty + qty);
      return;
    }

    final line = CartLine(
      productId: item.id,
      variantOptionId: variantOption?.id,
      qty: qty,
      priceSnapshotCentavos: item.priceCentavos,
      productTitle: item.title,
      productSku: item.sku,
      variantLabel: variantOption?.label,
    );

    state = CartState(lines: [...state.lines, line]);
  }

  /// Elimina la línea con el [productId] y [variantOptionId] dados.
  void removeLine(String productId, [String? variantOptionId]) {
    state = CartState(
      lines: state.lines
          .where((l) =>
              !(l.productId == productId &&
                  l.variantOptionId == variantOptionId))
          .toList(),
    );
  }

  /// Actualiza la cantidad de una línea. Si [qty] ≤ 0, la elimina.
  void updateQty(String productId, String? variantOptionId, int qty) {
    if (qty <= 0) {
      removeLine(productId, variantOptionId);
      return;
    }
    _updateQty(productId, variantOptionId, qty);
  }

  /// Vacía el carrito.
  void clear() => state = const CartState();

  // ── Private helpers ───────────────────────────────────────────────────────

  CartLine? _findLine(String productId, String? variantOptionId) {
    try {
      return state.lines.firstWhere(
        (l) =>
            l.productId == productId && l.variantOptionId == variantOptionId,
      );
    } catch (_) {
      return null;
    }
  }

  void _updateQty(String productId, String? variantOptionId, int qty) {
    state = CartState(
      lines: state.lines.map((l) {
        if (l.productId == productId &&
            l.variantOptionId == variantOptionId) {
          return l.copyWith(qty: qty);
        }
        return l;
      }).toList(),
    );
  }
}

/// Provider del carrito de materiales.
///
/// autoDispose: el carrito se descarta automáticamente cuando ya no hay
/// listeners activos (ej. al salir del flujo de pedidos).
final cartProvider =
    NotifierProvider.autoDispose<CartNotifier, CartState>(CartNotifier.new);
