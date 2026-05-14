import '../../domain/entities/material_disponibilidad.dart';
import '../../domain/entities/orden_line.dart';

/// Modelo de datos para [OrdenLine].
class OrdenLineModel extends OrdenLine {
  const OrdenLineModel({
    required super.id,
    required super.productId,
    super.variantOptionId,
    required super.qty,
    required super.priceCentavos,
    required super.disponibilidad,
    super.qtyDisponible,
    required super.lineTotalCentavos,
    required super.product,
  });

  factory OrdenLineModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] as Map<String, dynamic>?;

    return OrdenLineModel(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? json['productId'] ?? '').toString(),
      variantOptionId:
          (json['variant_option_id'] ?? json['variantOptionId'])?.toString(),
      qty: (json['qty'] ?? 1) as int,
      priceCentavos:
          (json['price_centavos'] ?? json['priceCentavos'] ?? 0) as int,
      disponibilidad: MaterialDisponibilidadX.fromString(
        (json['disponibilidad'] ?? 'pendiente').toString(),
      ),
      qtyDisponible: (json['qty_disponible'] ?? json['qtyDisponible']) as int?,
      lineTotalCentavos: (json['line_total_centavos'] ??
          json['lineTotalCentavos'] ??
          0) as int,
      product: productJson != null
          ? _productFromJson(productJson)
          : OrdenLineProduct(
              id: (json['product_id'] ?? '').toString(),
              sku: '',
              title: '',
            ),
    );
  }

  static OrdenLineProduct _productFromJson(Map<String, dynamic> json) {
    return OrdenLineProduct(
      id: (json['id'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      if (variantOptionId != null) 'variant_option_id': variantOptionId,
      'qty': qty,
      'price_centavos': priceCentavos,
      'disponibilidad': disponibilidad.toApiString(),
      if (qtyDisponible != null) 'qty_disponible': qtyDisponible,
      'line_total_centavos': lineTotalCentavos,
      'product': {
        'id': product.id,
        'sku': product.sku,
        'title': product.title,
      },
    };
  }

  OrdenLine toEntity() => OrdenLine(
        id: id,
        productId: productId,
        variantOptionId: variantOptionId,
        qty: qty,
        priceCentavos: priceCentavos,
        disponibilidad: disponibilidad,
        qtyDisponible: qtyDisponible,
        lineTotalCentavos: lineTotalCentavos,
        product: product,
      );
}
