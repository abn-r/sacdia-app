import 'package:equatable/equatable.dart';

/// Propósito de una orden de pago territorial.
enum PaymentOrderPurpose { insurance, camporee }

extension PaymentOrderPurposeApi on PaymentOrderPurpose {
  String get apiValue {
    switch (this) {
      case PaymentOrderPurpose.insurance:
        return 'INSURANCE';
      case PaymentOrderPurpose.camporee:
        return 'CAMPOREE';
    }
  }

  static PaymentOrderPurpose fromApi(String value) {
    switch (value) {
      case 'CAMPOREE':
        return PaymentOrderPurpose.camporee;
      case 'INSURANCE':
      default:
        return PaymentOrderPurpose.insurance;
    }
  }
}

/// Estado de la orden dentro de su máquina de estados.
enum PaymentOrderStatus {
  issued,
  proofSubmitted,
  approved,
  proofRejected,
  cancelled,
  expired,
}

extension PaymentOrderStatusApi on PaymentOrderStatus {
  String get apiValue {
    switch (this) {
      case PaymentOrderStatus.issued:
        return 'ISSUED';
      case PaymentOrderStatus.proofSubmitted:
        return 'PROOF_SUBMITTED';
      case PaymentOrderStatus.approved:
        return 'APPROVED';
      case PaymentOrderStatus.proofRejected:
        return 'PROOF_REJECTED';
      case PaymentOrderStatus.cancelled:
        return 'CANCELLED';
      case PaymentOrderStatus.expired:
        return 'EXPIRED';
    }
  }

  static PaymentOrderStatus fromApi(String value) {
    switch (value) {
      case 'PROOF_SUBMITTED':
        return PaymentOrderStatus.proofSubmitted;
      case 'APPROVED':
        return PaymentOrderStatus.approved;
      case 'PROOF_REJECTED':
        return PaymentOrderStatus.proofRejected;
      case 'CANCELLED':
        return PaymentOrderStatus.cancelled;
      case 'EXPIRED':
        return PaymentOrderStatus.expired;
      case 'ISSUED':
      default:
        return PaymentOrderStatus.issued;
    }
  }
}

/// Estado del comprobante subido a la orden.
enum PaymentOrderProofStatus { submitted, approved, rejected }

extension PaymentOrderProofStatusApi on PaymentOrderProofStatus {
  static PaymentOrderProofStatus fromApi(String value) {
    switch (value) {
      case 'APPROVED':
        return PaymentOrderProofStatus.approved;
      case 'REJECTED':
        return PaymentOrderProofStatus.rejected;
      case 'SUBMITTED':
      default:
        return PaymentOrderProofStatus.submitted;
    }
  }
}

/// Línea (beneficiario) de una orden de pago.
class PaymentOrderLine extends Equatable {
  final String lineId;
  final int sequence;
  final String beneficiaryUserId;
  final int unitCostCentavos;

  const PaymentOrderLine({
    required this.lineId,
    required this.sequence,
    required this.beneficiaryUserId,
    required this.unitCostCentavos,
  });

  @override
  List<Object?> get props => [lineId, sequence, beneficiaryUserId];
}

/// Comprobante de pago subido a una orden.
class PaymentOrderProof extends Equatable {
  final String proofId;
  final String fileName;
  final String mimeType;
  final PaymentOrderProofStatus status;
  final String? rejectReason;
  final DateTime createdAt;

  const PaymentOrderProof({
    required this.proofId,
    required this.fileName,
    required this.mimeType,
    required this.status,
    required this.createdAt,
    this.rejectReason,
  });

  @override
  List<Object?> get props => [proofId, status, rejectReason];
}

/// Orden de pago territorial (seguro o camporee).
class PaymentOrder extends Equatable {
  final String orderId;
  final PaymentOrderPurpose purpose;
  final String folioReference;
  final String currency;
  final int unitCostCentavos;
  final int totalCentavos;
  final PaymentOrderStatus status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final List<PaymentOrderLine> lines;
  final List<PaymentOrderProof> proofs;

  const PaymentOrder({
    required this.orderId,
    required this.purpose,
    required this.folioReference,
    required this.currency,
    required this.unitCostCentavos,
    required this.totalCentavos,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.lines = const [],
    this.proofs = const [],
  });

  /// Comprobante más reciente (backend los ordena descendente).
  PaymentOrderProof? get latestProof => proofs.isEmpty ? null : proofs.first;

  bool get canUploadProof =>
      status == PaymentOrderStatus.issued ||
      status == PaymentOrderStatus.proofRejected;

  bool get canCancel =>
      status == PaymentOrderStatus.issued ||
      status == PaymentOrderStatus.proofRejected;

  @override
  List<Object?> get props => [orderId, status, proofs];
}

/// Ciclo de seguro aplicable a la sección activa (para emitir órdenes).
class InsuranceCycleOption extends Equatable {
  final int cycleConfigId;
  final String productName;
  final int unitCostCentavos;
  final DateTime? purchaseDeadline;

  const InsuranceCycleOption({
    required this.cycleConfigId,
    required this.productName,
    required this.unitCostCentavos,
    this.purchaseDeadline,
  });

  @override
  List<Object?> get props => [cycleConfigId];
}

/// Disponibilidad del flujo de órdenes para la sección activa del usuario.
class PaymentOrdersContext extends Equatable {
  final bool enabled;
  final int localFieldId;
  final int clubSectionId;
  final List<InsuranceCycleOption> insuranceCycles;

  const PaymentOrdersContext({
    required this.enabled,
    required this.localFieldId,
    required this.clubSectionId,
    this.insuranceCycles = const [],
  });

  @override
  List<Object?> get props => [enabled, localFieldId, clubSectionId];
}

/// Solicitud de reasignación de cobertura de seguro.
class InsuranceReassignment extends Equatable {
  final int requestId;
  final int insuranceAssignmentId;
  final String fromUserId;
  final String toUserId;
  final String? reason;
  final String status;
  final String? rejectReason;
  final DateTime createdAt;

  const InsuranceReassignment({
    required this.requestId,
    required this.insuranceAssignmentId,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    this.reason,
    this.rejectReason,
  });

  @override
  List<Object?> get props => [requestId, status];
}
