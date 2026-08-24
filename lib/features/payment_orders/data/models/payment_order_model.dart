import '../../domain/entities/payment_order.dart';

/// Modelo de línea de orden de pago.
class PaymentOrderLineModel {
  final String lineId;
  final int sequence;
  final String beneficiaryUserId;
  final int unitCostCentavos;

  const PaymentOrderLineModel({
    required this.lineId,
    required this.sequence,
    required this.beneficiaryUserId,
    required this.unitCostCentavos,
  });

  factory PaymentOrderLineModel.fromJson(Map<String, dynamic> json) {
    return PaymentOrderLineModel(
      lineId: json['field_payment_order_line_id']?.toString() ?? '',
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      beneficiaryUserId: json['beneficiary_user_id']?.toString() ?? '',
      unitCostCentavos: (json['unit_cost_centavos'] as num?)?.toInt() ?? 0,
    );
  }

  PaymentOrderLine toEntity() => PaymentOrderLine(
        lineId: lineId,
        sequence: sequence,
        beneficiaryUserId: beneficiaryUserId,
        unitCostCentavos: unitCostCentavos,
      );
}

/// Modelo de comprobante de orden de pago.
class PaymentOrderProofModel {
  final String proofId;
  final String fileName;
  final String mimeType;
  final String status;
  final String? rejectReason;
  final DateTime createdAt;

  const PaymentOrderProofModel({
    required this.proofId,
    required this.fileName,
    required this.mimeType,
    required this.status,
    required this.createdAt,
    this.rejectReason,
  });

  factory PaymentOrderProofModel.fromJson(Map<String, dynamic> json) {
    return PaymentOrderProofModel(
      proofId: json['field_payment_order_proof_id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SUBMITTED',
      rejectReason: json['reject_reason']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  PaymentOrderProof toEntity() => PaymentOrderProof(
        proofId: proofId,
        fileName: fileName,
        mimeType: mimeType,
        status: PaymentOrderProofStatusApi.fromApi(status),
        rejectReason: rejectReason,
        createdAt: createdAt,
      );
}

/// Modelo de orden de pago territorial.
class PaymentOrderModel {
  final String orderId;
  final String purpose;
  final String folioReference;
  final String currency;
  final int unitCostCentavos;
  final int totalCentavos;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final List<PaymentOrderLineModel> lines;
  final List<PaymentOrderProofModel> proofs;

  const PaymentOrderModel({
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

  factory PaymentOrderModel.fromJson(Map<String, dynamic> json) {
    return PaymentOrderModel(
      orderId: json['field_payment_order_id']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? 'INSURANCE',
      folioReference: json['folio_reference']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'MXN',
      unitCostCentavos: (json['unit_cost_centavos'] as num?)?.toInt() ?? 0,
      totalCentavos: (json['total_centavos'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'ISSUED',
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((e) => PaymentOrderLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      proofs: (json['proofs'] as List<dynamic>? ?? [])
          .map(
              (e) => PaymentOrderProofModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  PaymentOrder toEntity() => PaymentOrder(
        orderId: orderId,
        purpose: PaymentOrderPurposeApi.fromApi(purpose),
        folioReference: folioReference,
        currency: currency,
        unitCostCentavos: unitCostCentavos,
        totalCentavos: totalCentavos,
        status: PaymentOrderStatusApi.fromApi(status),
        expiresAt: expiresAt,
        createdAt: createdAt,
        lines: lines.map((l) => l.toEntity()).toList(),
        proofs: proofs.map((p) => p.toEntity()).toList(),
      );
}

/// Modelo del contexto de disponibilidad de órdenes.
class PaymentOrdersContextModel {
  final bool enabled;
  final int localFieldId;
  final int clubSectionId;
  final List<InsuranceCycleOptionModel> insuranceCycles;

  const PaymentOrdersContextModel({
    required this.enabled,
    required this.localFieldId,
    required this.clubSectionId,
    this.insuranceCycles = const [],
  });

  factory PaymentOrdersContextModel.fromJson(Map<String, dynamic> json) {
    return PaymentOrdersContextModel(
      enabled: json['enabled'] == true,
      localFieldId: (json['local_field_id'] as num?)?.toInt() ?? 0,
      clubSectionId: (json['club_section_id'] as num?)?.toInt() ?? 0,
      insuranceCycles: (json['insurance_cycles'] as List<dynamic>? ?? [])
          .map((e) =>
              InsuranceCycleOptionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  PaymentOrdersContext toEntity() => PaymentOrdersContext(
        enabled: enabled,
        localFieldId: localFieldId,
        clubSectionId: clubSectionId,
        insuranceCycles: insuranceCycles.map((c) => c.toEntity()).toList(),
      );
}

/// Modelo de ciclo de seguro aplicable.
class InsuranceCycleOptionModel {
  final int cycleConfigId;
  final String productName;
  final int unitCostCentavos;
  final DateTime? purchaseDeadline;

  const InsuranceCycleOptionModel({
    required this.cycleConfigId,
    required this.productName,
    required this.unitCostCentavos,
    this.purchaseDeadline,
  });

  factory InsuranceCycleOptionModel.fromJson(Map<String, dynamic> json) {
    // unit_cost llega como Decimal serializado (string) en pesos.
    final rawCost = json['unit_cost'];
    final costPesos = rawCost is num
        ? rawCost.toDouble()
        : double.tryParse(rawCost?.toString() ?? '') ?? 0;
    return InsuranceCycleOptionModel(
      cycleConfigId: (json['insurance_cycle_config_id'] as num?)?.toInt() ?? 0,
      productName:
          (json['product'] as Map<String, dynamic>?)?['name']?.toString() ?? '',
      unitCostCentavos: (costPesos * 100).round(),
      purchaseDeadline:
          DateTime.tryParse(json['purchase_deadline']?.toString() ?? ''),
    );
  }

  InsuranceCycleOption toEntity() => InsuranceCycleOption(
        cycleConfigId: cycleConfigId,
        productName: productName,
        unitCostCentavos: unitCostCentavos,
        purchaseDeadline: purchaseDeadline,
      );
}

/// Modelo de solicitud de reasignación de seguro.
class InsuranceReassignmentModel {
  final int requestId;
  final int insuranceAssignmentId;
  final String fromUserId;
  final String toUserId;
  final String? reason;
  final String status;
  final String? rejectReason;
  final DateTime createdAt;

  const InsuranceReassignmentModel({
    required this.requestId,
    required this.insuranceAssignmentId,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    this.reason,
    this.rejectReason,
  });

  factory InsuranceReassignmentModel.fromJson(Map<String, dynamic> json) {
    return InsuranceReassignmentModel(
      requestId:
          (json['insurance_reassignment_request_id'] as num?)?.toInt() ?? 0,
      insuranceAssignmentId:
          (json['insurance_assignment_id'] as num?)?.toInt() ?? 0,
      fromUserId: json['from_user_id']?.toString() ?? '',
      toUserId: json['to_user_id']?.toString() ?? '',
      reason: json['reason']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      rejectReason: json['reject_reason']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  InsuranceReassignment toEntity() => InsuranceReassignment(
        requestId: requestId,
        insuranceAssignmentId: insuranceAssignmentId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        reason: reason,
        status: status,
        rejectReason: rejectReason,
        createdAt: createdAt,
      );
}
