import 'package:equatable/equatable.dart';

import 'camporee_order_product.dart';

/// Ventana de pedidos del camporee. `orders_enabled=false` es fail-closed.
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

/// Oferta = producto × camporee + precio. El cliente no envía el precio al emitir.
class CamporeeOrderOffering extends Equatable {
  final String offeringId;
  final int priceCentavos;
  final bool active;
  final int sortOrder;
  final CamporeeOrderProduct product;

  const CamporeeOrderOffering({
    required this.offeringId,
    required this.priceCentavos,
    required this.active,
    required this.sortOrder,
    required this.product,
  });

  bool get requiresOption => product.requiresOption;

  @override
  List<Object?> get props => [offeringId, priceCentavos];
}

typedef CamporeeOrderOfferingsResult = CamporeeOrderOfferingsCatalog;

class CamporeeOrderOfferingsCatalog extends Equatable {
  final CamporeeOrderSettings settings;
  final List<CamporeeOrderOffering> items;

  const CamporeeOrderOfferingsCatalog({
    required this.settings,
    this.items = const [],
  });

  @override
  List<Object?> get props => [settings, items];
}
