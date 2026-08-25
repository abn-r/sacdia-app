import 'package:equatable/equatable.dart';

import 'camporee_order_product.dart';

/// Ventana de pedidos del camporee (kill switch + fechas).
class CamporeeOrderSettings extends Equatable {
  final bool ordersEnabled;
  final DateTime? ordersOpensAt;
  final DateTime? ordersDeadline;

  const CamporeeOrderSettings({
    required this.ordersEnabled,
    this.ordersOpensAt,
    this.ordersDeadline,
  });

  @override
  List<Object?> get props => [ordersEnabled, ordersOpensAt, ordersDeadline];
}

/// Oferta de un producto en un camporee concreto (precio del evento).
class CamporeeOrderOffering extends Equatable {
  final String offeringId;
  final int? localCamporeeId;
  final int? unionCamporeeId;
  final String productId;
  final int priceCentavos;
  final bool active;
  final int sortOrder;
  final CamporeeOrderProduct product;

  const CamporeeOrderOffering({
    required this.offeringId,
    required this.productId,
    required this.priceCentavos,
    required this.active,
    required this.sortOrder,
    required this.product,
    this.localCamporeeId,
    this.unionCamporeeId,
  });

  /// NONE no exige talla; LETTER/NUMERIC sí.
  bool get requiresOption => product.sizeScheme.requiresOption;

  @override
  List<Object?> get props => [offeringId, productId, priceCentavos, active];
}

/// Respuesta de GET .../order-offerings: settings + ítems.
class CamporeeOrderOfferingsResult extends Equatable {
  final CamporeeOrderSettings settings;
  final List<CamporeeOrderOffering> items;

  const CamporeeOrderOfferingsResult({
    required this.settings,
    this.items = const [],
  });

  @override
  List<Object?> get props => [settings, items];
}
