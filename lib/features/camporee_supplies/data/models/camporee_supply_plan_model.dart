import '../../../camporee_orders/domain/entities/camporee_order.dart';
import '../../domain/entities/camporee_supply_plan.dart';

class CamporeeSupplyPlanModel {
  static CamporeeSupplyPlanEnvelope envelopeFromJson(
    Map<String, dynamic> json, {
    required int camporeeId,
    required CamporeeKind camporeeType,
  }) {
    final catalogJson = json['catalog'];
    final planJson = json['plan'];
    return CamporeeSupplyPlanEnvelope(
      camporeeId: camporeeId,
      camporeeType: camporeeType,
      catalog: catalogFromJson(
        catalogJson is Map<String, dynamic> ? catalogJson : json,
      ),
      plan: planJson is Map<String, dynamic> ? planFromJson(planJson) : null,
    );
  }

  static CamporeeSupplyCatalog catalogFromJson(Map<String, dynamic> json) {
    final slots = json['slots'];
    final products = json['products'];
    return CamporeeSupplyCatalog(
      cutoff: json['supply_edit_cutoff_local_time']?.toString() ??
          json['cutoff']?.toString() ??
          '21:00',
      timezone: json['timezone']?.toString() ?? 'America/Mexico_City',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      slots: slots is List
          ? slots.whereType<Map<String, dynamic>>().map(slotFromJson).toList()
          : const [],
      products: products is List
          ? products
              .whereType<Map<String, dynamic>>()
              .map(productFromJson)
              .toList()
          : const [],
    );
  }

  static CamporeeSupplySlot slotFromJson(Map<String, dynamic> json) {
    return CamporeeSupplySlot(
      slotId: json['slot_id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      deliverTime: json['deliver_time']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  static CamporeeSupplyProduct productFromJson(Map<String, dynamic> json) {
    return CamporeeSupplyProduct(
      productId: json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      uom: json['uom']?.toString() ?? 'UNIT',
      unitCostCentavos: (json['unit_cost_centavos'] as num?)?.toInt() ?? 0,
    );
  }

  static CamporeeSupplyPlan planFromJson(Map<String, dynamic> json) {
    final lines = json['lines'];
    final payments = json['payments'];
    return CamporeeSupplyPlan(
      planId: json['plan_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DRAFT',
      committedTotalCentavos:
          (json['committed_total_centavos'] as num?)?.toInt() ?? 0,
      netCentavos: (json['net_centavos'] as num?)?.toInt() ?? 0,
      cutoff: json['cutoff']?.toString() ?? '21:00',
      timezone: json['timezone']?.toString() ?? 'America/Mexico_City',
      lines: lines is List
          ? lines.whereType<Map<String, dynamic>>().map(lineFromJson).toList()
          : const [],
      payments: payments is List
          ? payments
              .whereType<Map<String, dynamic>>()
              .map(paymentFromJson)
              .toList()
          : const [],
    );
  }

  static CamporeeSupplyLine lineFromJson(Map<String, dynamic> json) {
    return CamporeeSupplyLine(
      lineId: json['line_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      slotId: json['slot_id']?.toString() ?? '',
      slotLabel: json['slot_label']?.toString() ?? '',
      deliverTime: json['deliver_time']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      uom: json['uom']?.toString() ?? 'UNIT',
      qty: json['qty']?.toString() ?? '0.000',
      deliveredQty: json['delivered_qty']?.toString() ?? '0.000',
      unitCostCentavos: (json['unit_cost_centavos'] as num?)?.toInt() ?? 0,
      lineTotalCentavos: (json['line_total_centavos'] as num?)?.toInt() ?? 0,
    );
  }

  static CamporeeSupplyPayment paymentFromJson(Map<String, dynamic> json) {
    return CamporeeSupplyPayment(
      paymentId: json['payment_id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'PRINCIPAL',
      parentId: json['parent_id']?.toString(),
      folioReference: json['folio_reference']?.toString() ?? '',
      totalCentavos: (json['total_centavos'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'ISSUED',
    );
  }
}
