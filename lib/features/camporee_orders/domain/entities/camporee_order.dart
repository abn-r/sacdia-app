import 'package:equatable/equatable.dart';

/// Tipo de camporee al que pertenece el pedido (XOR local/unión).
enum CamporeeOrderCamporeeType { local, union }

extension CamporeeOrderCamporeeTypeApi on CamporeeOrderCamporeeType {
  String get apiValue {
    switch (this) {
      case CamporeeOrderCamporeeType.local:
        return 'local';
      case CamporeeOrderCamporeeType.union:
        return 'union';
    }
  }

  static CamporeeOrderCamporeeType fromApi(String value) {
    switch (value) {
      case 'union':
        return CamporeeOrderCamporeeType.union;
      case 'local':
      default:
        return CamporeeOrderCamporeeType.local;
    }
  }
}

/// Estado financiero del pedido de mercancía (no es inscripción).
enum CamporeeOrderStatus {
  issued,
  proofSubmitted,
  proofRejected,
  paid,
  delivered,
  cancelled,
  expired,
}

extension CamporeeOrderStatusApi on CamporeeOrderStatus {
  String get apiValue {
    switch (this) {
      case CamporeeOrderStatus.issued:
        return 'ISSUED';
      case CamporeeOrderStatus.proofSubmitted:
        return 'PROOF_SUBMITTED';
      case CamporeeOrderStatus.proofRejected:
        return 'PROOF_REJECTED';
      case CamporeeOrderStatus.paid:
        return 'PAID';
      case CamporeeOrderStatus.delivered:
        return 'DELIVERED';
      case CamporeeOrderStatus.cancelled:
        return 'CANCELLED';
      case CamporeeOrderStatus.expired:
        return 'EXPIRED';
    }
  }

  static CamporeeOrderStatus fromApi(String value) {
    switch (value) {
      case 'PROOF_SUBMITTED':
        return CamporeeOrderStatus.proofSubmitted;
      case 'PROOF_REJECTED':
        return CamporeeOrderStatus.proofRejected;
      case 'PAID':
        return CamporeeOrderStatus.paid;
      case 'DELIVERED':
        return CamporeeOrderStatus.delivered;
      case 'CANCELLED':
        return CamporeeOrderStatus.cancelled;
      case 'EXPIRED':
        return CamporeeOrderStatus.expired;
      case 'ISSUED':
      default:
        return CamporeeOrderStatus.issued;
    }
  }
}

/// Avance de distribución sección → miembro (derivado de las líneas).
enum CamporeeOrderDistributionStatus { notStarted, partial, complete }

extension CamporeeOrderDistributionStatusApi on CamporeeOrderDistributionStatus {
  String get apiValue {
    switch (this) {
      case CamporeeOrderDistributionStatus.notStarted:
        return 'NOT_STARTED';
      case CamporeeOrderDistributionStatus.partial:
        return 'PARTIAL';
      case CamporeeOrderDistributionStatus.complete:
        return 'COMPLETE';
    }
  }

  static CamporeeOrderDistributionStatus fromApi(String value) {
    switch (value) {
      case 'PARTIAL':
        return CamporeeOrderDistributionStatus.partial;
      case 'COMPLETE':
        return CamporeeOrderDistributionStatus.complete;
      case 'NOT_STARTED':
      default:
        return CamporeeOrderDistributionStatus.notStarted;
    }
  }
}

/// Estado del comprobante de pago del pedido.
enum CamporeeOrderProofStatus { submitted, approved, rejected }

extension CamporeeOrderProofStatusApi on CamporeeOrderProofStatus {
  static CamporeeOrderProofStatus fromApi(String value) {
    switch (value) {
      case 'APPROVED':
        return CamporeeOrderProofStatus.approved;
      case 'REJECTED':
        return CamporeeOrderProofStatus.rejected;
      case 'SUBMITTED':
      default:
        return CamporeeOrderProofStatus.submitted;
    }
  }
}

/// Deriva el avance de distribución a partir de `delivered_to_member_at`.
///
/// Coincide con el helper del backend: vacío o ninguna fecha → NOT_STARTED;
/// todas con fecha → COMPLETE; mezcla → PARTIAL.
CamporeeOrderDistributionStatus deriveDistributionStatus(
  Iterable<CamporeeOrderLine> lines,
) {
  final list = lines.toList();
  if (list.isEmpty) {
    return CamporeeOrderDistributionStatus.notStarted;
  }
  final delivered =
      list.where((line) => line.deliveredToMemberAt != null).length;
  if (delivered == 0) {
    return CamporeeOrderDistributionStatus.notStarted;
  }
  if (delivered == list.length) {
    return CamporeeOrderDistributionStatus.complete;
  }
  return CamporeeOrderDistributionStatus.partial;
}

/// Línea de emisión: el cliente nunca manda montos ni autoridad de club.
class CamporeeOrderCreateLine extends Equatable {
  final int camporeeMemberId;
  final String offeringId;
  final String? optionId;
  final int qty;

  const CamporeeOrderCreateLine({
    required this.camporeeMemberId,
    required this.offeringId,
    required this.qty,
    this.optionId,
  });

  /// Payload de create. Omite `option_id` cuando el esquema de talla es NONE.
  Map<String, dynamic> toJson() => {
        'camporee_member_id': camporeeMemberId,
        'offering_id': offeringId,
        if (optionId != null) 'option_id': optionId,
        'qty': qty,
      };

  @override
  List<Object?> get props => [camporeeMemberId, offeringId, optionId, qty];
}

/// Línea nominada (persona + oferta + talla). Fuente de verdad del pedido.
class CamporeeOrderLine extends Equatable {
  final String lineId;
  final int sequence;
  final int camporeeMemberId;
  final String beneficiaryUserId;
  final String beneficiaryNameSnapshot;
  final String offeringId;
  final String productId;
  final String? optionId;
  final String productTitleSnapshot;
  final String? optionLabelSnapshot;
  final int qty;
  final int unitPriceCentavos;
  final int lineTotalCentavos;
  final DateTime? deliveredToMemberAt;
  final String? deliveredToMemberById;

  const CamporeeOrderLine({
    required this.lineId,
    required this.sequence,
    required this.camporeeMemberId,
    required this.beneficiaryUserId,
    required this.beneficiaryNameSnapshot,
    required this.offeringId,
    required this.productId,
    required this.productTitleSnapshot,
    required this.qty,
    required this.unitPriceCentavos,
    required this.lineTotalCentavos,
    this.optionId,
    this.optionLabelSnapshot,
    this.deliveredToMemberAt,
    this.deliveredToMemberById,
  });

  @override
  List<Object?> get props => [
        lineId,
        sequence,
        camporeeMemberId,
        optionId,
        qty,
        deliveredToMemberAt,
      ];
}

/// Consolidado derivado que el API calcula; el cliente solo lo parsea.
class CamporeeOrderSummaryItem extends Equatable {
  final String productTitleSnapshot;
  final String? optionLabelSnapshot;
  final int qty;
  final int subtotalCentavos;

  const CamporeeOrderSummaryItem({
    required this.productTitleSnapshot,
    required this.qty,
    required this.subtotalCentavos,
    this.optionLabelSnapshot,
  });

  @override
  List<Object?> get props =>
      [productTitleSnapshot, optionLabelSnapshot, qty, subtotalCentavos];
}

/// Comprobante vigente (URL firmada de lectura).
class CamporeeOrderProof extends Equatable {
  final String? url;
  final int? expiresIn;
  final String fileName;
  final String mimeType;
  final CamporeeOrderProofStatus status;
  final String? uploadedById;
  final DateTime createdAt;

  const CamporeeOrderProof({
    required this.fileName,
    required this.mimeType,
    required this.status,
    required this.createdAt,
    this.url,
    this.expiresIn,
    this.uploadedById,
  });

  @override
  List<Object?> get props => [fileName, status, url];
}

/// Pedido de mercancía de camporee (no es Field Payment Order de inscripción).
class CamporeeOrder extends Equatable {
  final String orderId;
  final int? localCamporeeId;
  final int? unionCamporeeId;
  final String folioReference;
  final CamporeeOrderStatus status;
  final String currency;
  final int totalCentavos;
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool authorizedWithoutProof;
  final CamporeeOrderDistributionStatus distributionStatus;
  final List<CamporeeOrderLine> lines;
  final List<CamporeeOrderSummaryItem> summary;
  final String? bankName;
  final String? bankAccount;
  final String? bankClabe;
  final String? bankHolder;
  final String? cashInstructions;
  final String? extraNotes;

  const CamporeeOrder({
    required this.orderId,
    required this.folioReference,
    required this.status,
    required this.currency,
    required this.totalCentavos,
    required this.expiresAt,
    required this.createdAt,
    required this.authorizedWithoutProof,
    required this.distributionStatus,
    this.localCamporeeId,
    this.unionCamporeeId,
    this.lines = const [],
    this.summary = const [],
    this.bankName,
    this.bankAccount,
    this.bankClabe,
    this.bankHolder,
    this.cashInstructions,
    this.extraNotes,
  });

  bool get isUnionCamporee => unionCamporeeId != null;

  bool get canUploadProof =>
      status == CamporeeOrderStatus.issued ||
      status == CamporeeOrderStatus.proofRejected ||
      (authorizedWithoutProof &&
          (status == CamporeeOrderStatus.paid ||
              status == CamporeeOrderStatus.delivered));

  bool get canCancel =>
      status == CamporeeOrderStatus.issued ||
      status == CamporeeOrderStatus.proofRejected;

  bool get canDistributeToMember => status == CamporeeOrderStatus.delivered;

  @override
  List<Object?> get props => [
        orderId,
        localCamporeeId,
        unionCamporeeId,
        status,
        authorizedWithoutProof,
        distributionStatus,
      ];
}
