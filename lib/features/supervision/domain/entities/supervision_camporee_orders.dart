import 'package:equatable/equatable.dart';

import '../../../camporee_orders/domain/entities/camporee_order_offering.dart';
import '../../../camporee_orders/domain/entities/camporee_order_product.dart';

/// What the merchandise screen needs in one read.
class SupervisionCamporeeOrderConfig extends Equatable {
  const SupervisionCamporeeOrderConfig({
    required this.settings,
    this.offerings = const [],
    this.products = const [],
  });

  final CamporeeOrderSettings settings;

  /// As the server returns them (inactive included).
  final List<CamporeeOrderOffering> offerings;

  /// Active library products, by title.
  final List<CamporeeOrderProduct> products;

  /// The ACTIVE offering of [productId], or null.
  CamporeeOrderOffering? activeOfferingOf(String productId) {
    for (final offering in offerings) {
      if (offering.active && offering.product.productId == productId) {
        return offering;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [
        settings,
        offerings
            .map((o) => [o.offeringId, o.priceCentavos, o.active])
            .toList(),
        products.map((p) => p.productId).toList(),
      ];
}

/// One row of the full replacement sent on save.
class SupervisionOfferingInput extends Equatable {
  const SupervisionOfferingInput({
    required this.productId,
    required this.priceCentavos,
    required this.sortOrder,
  });

  final String productId;
  final int priceCentavos;
  final int sortOrder;

  @override
  List<Object?> get props => [productId, priceCentavos, sortOrder];
}

/// Explicit patch of the order window: a field left unset is not sent;
/// `clear...` sends null (and wins over the value).
class SupervisionOrderSettingsPatch extends Equatable {
  const SupervisionOrderSettingsPatch({
    this.ordersEnabled,
    this.opensAt,
    this.clearOpensAt = false,
    this.deadline,
    this.clearDeadline = false,
  });

  final bool? ordersEnabled;
  final DateTime? opensAt;
  final bool clearOpensAt;
  final DateTime? deadline;
  final bool clearDeadline;

  @override
  List<Object?> get props =>
      [ordersEnabled, opensAt, clearOpensAt, deadline, clearDeadline];
}

/// Unit of measure of a supply product. Wire: KG, L, BAG, UNIT.
enum SupervisionSupplyUom { kg, l, bag, unit, unknown }

class SupervisionSupplySlot extends Equatable {
  const SupervisionSupplySlot({
    required this.id,
    required this.label,
    required this.deliverTime,
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;
  final String label;

  /// "HH:mm".
  final String deliverTime;
  final int sortOrder;
  final bool active;

  @override
  List<Object?> get props => [id, label, deliverTime, sortOrder, active];
}

class SupervisionSupplyProduct extends Equatable {
  const SupervisionSupplyProduct({
    required this.id,
    required this.name,
    required this.uom,
    required this.unitCostCentavos,
    this.active = true,
  });

  final String id;
  final String name;
  final SupervisionSupplyUom uom;
  final int unitCostCentavos;
  final bool active;

  @override
  List<Object?> get props => [id, name, uom, unitCostCentavos, active];
}

class SupervisionSupplyCatalog extends Equatable {
  const SupervisionSupplyCatalog({
    required this.cutoffTime,
    required this.timezone,
    this.slots = const [],
    this.products = const [],
  });

  /// "HH:mm".
  final String cutoffTime;
  final String timezone;
  final List<SupervisionSupplySlot> slots;
  final List<SupervisionSupplyProduct> products;

  @override
  List<Object?> get props => [cutoffTime, timezone, slots, products];
}
