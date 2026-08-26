import 'package:equatable/equatable.dart';

/// Tipo de camporee al que pertenece un pedido (XOR local/unión).
enum CamporeeKind { local, union }

/// Estado de un pedido de mercancía de camporee (no inscripción).
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

/// Avance derivado de entrega nominada (sección → miembro).
enum CamporeeOrderDistributionStatus { notStarted, partial, complete }

extension CamporeeOrderDistributionStatusApi
    on CamporeeOrderDistributionStatus {
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

/// Deriva el progreso desde líneas nominadas. Fuente de verdad = fechas, no un agregado persistido.
CamporeeOrderDistributionStatus deriveDistributionStatus(
  List<CamporeeOrderLine> lines,
) {
  if (lines.isEmpty) {
    return CamporeeOrderDistributionStatus.notStarted;
  }
  final delivered =
      lines.where((line) => line.deliveredToMemberAt != null).length;
  if (delivered == 0) {
    return CamporeeOrderDistributionStatus.notStarted;
  }
  if (delivered == lines.length) {
    return CamporeeOrderDistributionStatus.complete;
  }
  return CamporeeOrderDistributionStatus.partial;
}

/// Línea nominada: inscrito + oferta + talla + cantidad. El servidor fija precios.
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

  bool get deliveredToMember => deliveredToMemberAt != null;

  @override
  List<Object?> get props => [lineId, camporeeMemberId, deliveredToMemberAt];
}

/// Consolidado derivado `SUM(qty)` / `SUM(line_total)` por producto+talla.
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
  List<Object?> get props => [productTitleSnapshot, optionLabelSnapshot, qty];
}

/// Input de emisión. El cliente nunca manda montos ni ids de club/campo.
typedef CamporeeOrderCreateLine = CamporeeOrderLineInput;

class CamporeeOrderLineInput extends Equatable {
  final int camporeeMemberId;
  final String offeringId;
  final String? optionId;
  final int qty;

  const CamporeeOrderLineInput({
    required this.camporeeMemberId,
    required this.offeringId,
    required this.qty,
    this.optionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'camporee_member_id': camporeeMemberId,
      'offering_id': offeringId,
      if (optionId != null) 'option_id': optionId,
      'qty': qty,
    };
  }

  @override
  List<Object?> get props => [camporeeMemberId, offeringId, optionId, qty];
}

/// URL firmada del comprobante vigente.
class CamporeeOrderProofDownload extends Equatable {
  final String url;
  final int expiresIn;
  final String fileName;
  final String mimeType;
  final String status;
  final DateTime createdAt;

  const CamporeeOrderProofDownload({
    required this.url,
    required this.expiresIn,
    required this.fileName,
    required this.mimeType,
    required this.status,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [url, status];
}

/// Pedido de sección: un folio independiente (puede haber varios por camporee).
class CamporeeOrder extends Equatable {
  final String orderId;
  final int localFieldId;
  final int clubId;
  final int clubSectionId;
  final int? localCamporeeId;
  final int? unionCamporeeId;
  final String folioReference;
  final CamporeeOrderStatus status;
  final String currency;
  final int totalCentavos;
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool authorizedWithoutProof;
  final String? authorizationReason;
  final DateTime? deliveredToSectionAt;
  final List<CamporeeOrderLine> lines;
  final List<CamporeeOrderSummaryItem> summary;
  final CamporeeOrderDistributionStatus distributionStatus;

  const CamporeeOrder({
    required this.orderId,
    required this.localFieldId,
    required this.clubId,
    required this.clubSectionId,
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
    this.authorizationReason,
    this.deliveredToSectionAt,
    this.lines = const [],
    this.summary = const [],
  });

  CamporeeKind? get camporeeKind {
    if (localCamporeeId != null) return CamporeeKind.local;
    if (unionCamporeeId != null) return CamporeeKind.union;
    return null;
  }

  bool get canUploadProof =>
      status == CamporeeOrderStatus.issued ||
      status == CamporeeOrderStatus.proofRejected ||
      (authorizedWithoutProof &&
          (status == CamporeeOrderStatus.paid ||
              status == CamporeeOrderStatus.delivered));

  bool get canCancel =>
      status == CamporeeOrderStatus.issued ||
      status == CamporeeOrderStatus.proofRejected;

  bool get canDistribute => status == CamporeeOrderStatus.delivered;

  @override
  List<Object?> get props => [orderId, status, folioReference];
}
