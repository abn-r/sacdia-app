import 'package:equatable/equatable.dart';

import '../../../camporee_orders/domain/entities/camporee_order.dart';

class CamporeeSupplySlot extends Equatable {
  final String slotId;
  final String label;
  final String deliverTime;
  final int sortOrder;

  const CamporeeSupplySlot({
    required this.slotId,
    required this.label,
    required this.deliverTime,
    required this.sortOrder,
  });

  @override
  List<Object?> get props => [slotId];
}

class CamporeeSupplyProduct extends Equatable {
  final String productId;
  final String name;
  final String uom;
  final int unitCostCentavos;

  const CamporeeSupplyProduct({
    required this.productId,
    required this.name,
    required this.uom,
    required this.unitCostCentavos,
  });

  @override
  List<Object?> get props => [productId];
}

class CamporeeSupplyLineInput extends Equatable {
  final String date;
  final String slotId;
  final String productId;
  final double qty;

  const CamporeeSupplyLineInput({
    required this.date,
    required this.slotId,
    required this.productId,
    required this.qty,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'slot_id': slotId,
        'product_id': productId,
        'qty': qty,
      };

  @override
  List<Object?> get props => [date, slotId, productId, qty];
}

class CamporeeSupplyLine extends Equatable {
  final String lineId;
  final String date;
  final String slotId;
  final String slotLabel;
  final String deliverTime;
  final String productId;
  final String productName;
  final String uom;
  final String qty;
  final String deliveredQty;
  final int unitCostCentavos;
  final int lineTotalCentavos;

  const CamporeeSupplyLine({
    required this.lineId,
    required this.date,
    required this.slotId,
    required this.slotLabel,
    required this.deliverTime,
    required this.productId,
    required this.productName,
    required this.uom,
    required this.qty,
    required this.deliveredQty,
    required this.unitCostCentavos,
    required this.lineTotalCentavos,
  });

  CamporeeSupplyLineInput toInput() => CamporeeSupplyLineInput(
        date: date,
        slotId: slotId,
        productId: productId,
        qty: double.tryParse(qty) ?? 0,
      );

  @override
  List<Object?> get props => [lineId, qty];
}

class CamporeeSupplyPayment extends Equatable {
  final String paymentId;
  final String kind;
  final String? parentId;
  final String folioReference;
  final int totalCentavos;
  final String status;

  const CamporeeSupplyPayment({
    required this.paymentId,
    required this.kind,
    required this.folioReference,
    required this.totalCentavos,
    required this.status,
    this.parentId,
  });

  @override
  List<Object?> get props => [paymentId, status];
}

class CamporeeSupplyPlan extends Equatable {
  final String planId;
  final String status;
  final int committedTotalCentavos;
  final int netCentavos;
  final String cutoff;
  final String timezone;
  final List<CamporeeSupplyLine> lines;
  final List<CamporeeSupplyPayment> payments;

  const CamporeeSupplyPlan({
    required this.planId,
    required this.status,
    required this.committedTotalCentavos,
    required this.netCentavos,
    required this.cutoff,
    required this.timezone,
    required this.lines,
    required this.payments,
  });

  bool get isDraft => status == 'DRAFT';
  bool get isSubmitted => status == 'SUBMITTED';

  @override
  List<Object?> get props => [planId, status, netCentavos];
}

class CamporeeSupplyCatalog extends Equatable {
  final String cutoff;
  final String timezone;
  final String startDate;
  final String endDate;
  final List<CamporeeSupplySlot> slots;
  final List<CamporeeSupplyProduct> products;

  const CamporeeSupplyCatalog({
    required this.cutoff,
    required this.timezone,
    required this.startDate,
    required this.endDate,
    required this.slots,
    required this.products,
  });

  bool get isReady => slots.isNotEmpty && products.isNotEmpty;

  @override
  List<Object?> get props => [cutoff, slots, products];
}

class CamporeeSupplyPlanEnvelope extends Equatable {
  final CamporeeSupplyPlan? plan;
  final CamporeeSupplyCatalog catalog;
  final CamporeeKind camporeeType;
  final int camporeeId;

  const CamporeeSupplyPlanEnvelope({
    required this.catalog,
    required this.camporeeType,
    required this.camporeeId,
    this.plan,
  });

  @override
  List<Object?> get props => [plan, catalog];
}
