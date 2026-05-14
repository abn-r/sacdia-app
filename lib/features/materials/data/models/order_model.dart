import '../../domain/entities/material_delivery.dart';
import '../../domain/entities/material_status.dart';
import '../../domain/entities/order.dart';
import 'receipt_model.dart';
import 'order_line_model.dart';

/// Modelo de datos para [Order].
///
/// Mapea la respuesta JSON de POST /materials/orders, GET /materials/orders/:folio,
/// y GET /materials/orders/history.
class OrderModel extends Order {
  const OrderModel({
    required super.id,
    super.folioReferencia,
    required super.status,
    required super.clubSectionId,
    required super.createdBy,
    super.approvedBy,
    super.validatedBy,
    super.deliveredBy,
    super.cancelledBy,
    required super.subtotalCentavos,
    required super.envioCentavos,
    required super.totalCentavos,
    required super.delivery,
    super.notas,
    super.cancelReason,
    super.bankName,
    super.bankAccountClabe,
    super.accountHolder,
    super.pickupAddress,
    required super.createdAt,
    super.approvedAt,
    super.paidAt,
    super.deliveredAt,
    super.cancelledAt,
    required super.lines,
    required super.receipts,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List<dynamic>? ?? [];
    // JSON key stays Spanish — backend contract
    final rawReceipts = json['comprobantes'] as List<dynamic>? ?? [];

    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return OrderModel(
      id: (json['id'] ?? '').toString(),
      folioReferencia:
          (json['folio_referencia'] ?? json['folioReferencia'])?.toString(),
      status: MaterialStatusX.fromString(
        (json['estado'] ?? 'en_revision').toString(),
      ),
      clubSectionId:
          (json['club_section_id'] ?? json['clubSectionId'] as num? ?? 0)
              .toInt(),
      createdBy: (json['created_by'] ?? json['createdBy'] ?? '').toString(),
      approvedBy: (json['approved_by'] ?? json['approvedBy'])?.toString(),
      validatedBy: (json['validated_by'] ?? json['validatedBy'])?.toString(),
      deliveredBy: (json['delivered_by'] ?? json['deliveredBy'])?.toString(),
      cancelledBy: (json['cancelled_by'] ?? json['cancelledBy'])?.toString(),
      subtotalCentavos:
          (json['subtotal_centavos'] ?? json['subtotalCentavos'] ?? 0) as int,
      envioCentavos:
          (json['envio_centavos'] ?? json['envioCentavos'] ?? 0) as int,
      totalCentavos:
          (json['total_centavos'] ?? json['totalCentavos'] ?? 0) as int,
      delivery: MaterialDeliveryX.fromString(
        (json['entrega'] ?? 'recoger').toString(),
      ),
      notas: json['notas']?.toString(),
      cancelReason: (json['cancel_reason'] ?? json['cancelReason'])?.toString(),
      bankName: (json['bank_name'] ?? json['bankName'])?.toString(),
      bankAccountClabe:
          (json['bank_account_clabe'] ?? json['bankAccountClabe'])?.toString(),
      accountHolder:
          (json['account_holder'] ?? json['accountHolder'])?.toString(),
      pickupAddress:
          (json['pickup_address'] ?? json['pickupAddress'])?.toString(),
      createdAt:
          parseDate(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      approvedAt: parseDate(json['approved_at'] ?? json['approvedAt']),
      paidAt: parseDate(json['paid_at'] ?? json['paidAt']),
      deliveredAt: parseDate(json['delivered_at'] ?? json['deliveredAt']),
      cancelledAt: parseDate(json['cancelled_at'] ?? json['cancelledAt']),
      lines: rawLines
          .map((l) => OrderLineModel.fromJson(l as Map<String, dynamic>))
          .toList(),
      receipts: rawReceipts
          .map((c) => ReceiptModel.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (folioReferencia != null) 'folio_referencia': folioReferencia,
      'estado': status.toApiString(),
      'club_section_id': clubSectionId,
      'created_by': createdBy,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (validatedBy != null) 'validated_by': validatedBy,
      if (deliveredBy != null) 'delivered_by': deliveredBy,
      if (cancelledBy != null) 'cancelled_by': cancelledBy,
      'subtotal_centavos': subtotalCentavos,
      'envio_centavos': envioCentavos,
      'total_centavos': totalCentavos,
      'entrega': delivery.toApiString(),
      if (notas != null) 'notas': notas,
      if (cancelReason != null) 'cancel_reason': cancelReason,
      if (bankName != null) 'bank_name': bankName,
      if (bankAccountClabe != null) 'bank_account_clabe': bankAccountClabe,
      if (accountHolder != null) 'account_holder': accountHolder,
      if (pickupAddress != null) 'pickup_address': pickupAddress,
      'created_at': createdAt.toIso8601String(),
      if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
      if (paidAt != null) 'paid_at': paidAt!.toIso8601String(),
      if (deliveredAt != null) 'delivered_at': deliveredAt!.toIso8601String(),
      if (cancelledAt != null) 'cancelled_at': cancelledAt!.toIso8601String(),
      'lines': lines
          .map((l) => OrderLineModel(
                id: l.id,
                productId: l.productId,
                variantOptionId: l.variantOptionId,
                qty: l.qty,
                priceCentavos: l.priceCentavos,
                disponibilidad: l.disponibilidad,
                qtyDisponible: l.qtyDisponible,
                lineTotalCentavos: l.lineTotalCentavos,
                product: l.product,
              ).toJson())
          .toList(),
      'comprobantes': receipts
          .map((c) => ReceiptModel(
                id: c.id,
                orderId: c.orderId,
                r2Key: c.r2Key,
                fileName: c.fileName,
                mimeType: c.mimeType,
                sizeBytes: c.sizeBytes,
                montoCentavos: c.montoCentavos,
                refBancariaDeclarada: c.refBancariaDeclarada,
                fechaPago: c.fechaPago,
                status: c.status,
                signedUrl: c.signedUrl,
                uploadedBy: c.uploadedBy,
                validatedBy: c.validatedBy,
                rejectReason: c.rejectReason,
                createdAt: c.createdAt,
                validatedAt: c.validatedAt,
              ).toJson())
          .toList(),
    };
  }

  Order toEntity() => Order(
        id: id,
        folioReferencia: folioReferencia,
        status: status,
        clubSectionId: clubSectionId,
        createdBy: createdBy,
        approvedBy: approvedBy,
        validatedBy: validatedBy,
        deliveredBy: deliveredBy,
        cancelledBy: cancelledBy,
        subtotalCentavos: subtotalCentavos,
        envioCentavos: envioCentavos,
        totalCentavos: totalCentavos,
        delivery: delivery,
        notas: notas,
        cancelReason: cancelReason,
        bankName: bankName,
        bankAccountClabe: bankAccountClabe,
        accountHolder: accountHolder,
        pickupAddress: pickupAddress,
        createdAt: createdAt,
        approvedAt: approvedAt,
        paidAt: paidAt,
        deliveredAt: deliveredAt,
        cancelledAt: cancelledAt,
        lines: lines,
        receipts: receipts,
      );
}
