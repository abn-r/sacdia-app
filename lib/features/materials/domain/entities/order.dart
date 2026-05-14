import 'package:equatable/equatable.dart';

import 'receipt.dart';
import 'material_delivery.dart';
import 'material_status.dart';
import 'order_line.dart';

/// Orden de materiales completa.
///
/// Incluye líneas y comprobantes cuando la API los embeds (GET /orders/:folio).
/// Todos los montos en centavos (MXN).
class Order extends Equatable {
  final String id;

  /// Folio único asignado al aprobar la orden (ej. "SOL20260001").
  /// Null mientras la orden esté en estado `en_revision`.
  final String? folioReferencia;

  final MaterialStatus status;
  final int clubSectionId;
  final String createdBy;
  final String? approvedBy;
  final String? validatedBy;
  final String? deliveredBy;
  final String? cancelledBy;

  final int subtotalCentavos;
  final int envioCentavos;
  final int totalCentavos;

  final MaterialDelivery delivery;
  final String? notas;
  final String? cancelReason;

  // Snapshot del banco al momento de aprobación
  final String? bankName;
  final String? bankAccountClabe;
  final String? accountHolder;
  final String? pickupAddress;

  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;

  final List<OrderLine> lines;
  final List<Receipt> receipts;

  const Order({
    required this.id,
    this.folioReferencia,
    required this.status,
    required this.clubSectionId,
    required this.createdBy,
    this.approvedBy,
    this.validatedBy,
    this.deliveredBy,
    this.cancelledBy,
    required this.subtotalCentavos,
    required this.envioCentavos,
    required this.totalCentavos,
    required this.delivery,
    this.notas,
    this.cancelReason,
    this.bankName,
    this.bankAccountClabe,
    this.accountHolder,
    this.pickupAddress,
    required this.createdAt,
    this.approvedAt,
    this.paidAt,
    this.deliveredAt,
    this.cancelledAt,
    required this.lines,
    required this.receipts,
  });

  bool get isApproved => status == MaterialStatus.aprobada;
  bool get isPaid => status == MaterialStatus.pagada;
  bool get isDelivered => status == MaterialStatus.entregada;
  bool get isCancelled => status == MaterialStatus.cancelada;
  bool get isInReview => status == MaterialStatus.enRevision;
  bool get isTerminal => status.isTerminal;

  @override
  List<Object?> get props => [
        id,
        folioReferencia,
        status,
        clubSectionId,
        createdBy,
        subtotalCentavos,
        envioCentavos,
        totalCentavos,
        delivery,
        createdAt,
        lines,
        receipts,
      ];
}
