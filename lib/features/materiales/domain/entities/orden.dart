import 'package:equatable/equatable.dart';

import 'comprobante.dart';
import 'material_entrega.dart';
import 'material_estado.dart';
import 'orden_line.dart';

/// Orden de materiales completa.
///
/// Incluye líneas y comprobantes cuando la API los embeds (GET /ordenes/:folio).
/// Todos los montos en centavos (MXN).
class Orden extends Equatable {
  final String id;

  /// Folio único asignado al aprobar la orden (ej. "SOL20260001").
  /// Null mientras la orden esté en estado `en_revision`.
  final String? folioReferencia;

  final MaterialEstado estado;
  final int clubSectionId;
  final String createdBy;
  final String? approvedBy;
  final String? validatedBy;
  final String? deliveredBy;
  final String? cancelledBy;

  final int subtotalCentavos;
  final int envioCentavos;
  final int totalCentavos;

  final MaterialEntrega entrega;
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

  final List<OrdenLine> lines;
  final List<Comprobante> comprobantes;

  const Orden({
    required this.id,
    this.folioReferencia,
    required this.estado,
    required this.clubSectionId,
    required this.createdBy,
    this.approvedBy,
    this.validatedBy,
    this.deliveredBy,
    this.cancelledBy,
    required this.subtotalCentavos,
    required this.envioCentavos,
    required this.totalCentavos,
    required this.entrega,
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
    required this.comprobantes,
  });

  bool get isApproved => estado == MaterialEstado.aprobada;
  bool get isPaid => estado == MaterialEstado.pagada;
  bool get isDelivered => estado == MaterialEstado.entregada;
  bool get isCancelled => estado == MaterialEstado.cancelada;
  bool get isInReview => estado == MaterialEstado.enRevision;
  bool get isTerminal => estado.isTerminal;

  @override
  List<Object?> get props => [
        id,
        folioReferencia,
        estado,
        clubSectionId,
        createdBy,
        subtotalCentavos,
        envioCentavos,
        totalCentavos,
        entrega,
        createdAt,
        lines,
        comprobantes,
      ];
}
