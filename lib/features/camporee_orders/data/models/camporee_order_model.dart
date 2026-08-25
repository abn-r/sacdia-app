import '../../domain/entities/camporee_order.dart';

/// Modelo de línea nominada de un pedido de camporee.
class CamporeeOrderLineModel {
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

  const CamporeeOrderLineModel({
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

  factory CamporeeOrderLineModel.fromJson(Map<String, dynamic> json) {
    return CamporeeOrderLineModel(
      lineId: json['camporee_order_line_id']?.toString() ?? '',
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      camporeeMemberId: (json['camporee_member_id'] as num?)?.toInt() ?? 0,
      beneficiaryUserId: json['beneficiary_user_id']?.toString() ?? '',
      beneficiaryNameSnapshot:
          json['beneficiary_name_snapshot']?.toString() ?? '',
      offeringId: json['offering_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      optionId: json['option_id']?.toString(),
      productTitleSnapshot: json['product_title_snapshot']?.toString() ?? '',
      optionLabelSnapshot: json['option_label_snapshot']?.toString(),
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      unitPriceCentavos: (json['unit_price_centavos'] as num?)?.toInt() ?? 0,
      lineTotalCentavos: (json['line_total_centavos'] as num?)?.toInt() ?? 0,
      deliveredToMemberAt:
          DateTime.tryParse(json['delivered_to_member_at']?.toString() ?? ''),
      deliveredToMemberById: json['delivered_to_member_by_id']?.toString(),
    );
  }

  CamporeeOrderLine toEntity() => CamporeeOrderLine(
        lineId: lineId,
        sequence: sequence,
        camporeeMemberId: camporeeMemberId,
        beneficiaryUserId: beneficiaryUserId,
        beneficiaryNameSnapshot: beneficiaryNameSnapshot,
        offeringId: offeringId,
        productId: productId,
        optionId: optionId,
        productTitleSnapshot: productTitleSnapshot,
        optionLabelSnapshot: optionLabelSnapshot,
        qty: qty,
        unitPriceCentavos: unitPriceCentavos,
        lineTotalCentavos: lineTotalCentavos,
        deliveredToMemberAt: deliveredToMemberAt,
        deliveredToMemberById: deliveredToMemberById,
      );
}

/// Modelo del consolidado derivado. Se parsea; no se recalcula.
class CamporeeOrderSummaryItemModel {
  final String productTitleSnapshot;
  final String? optionLabelSnapshot;
  final int qty;
  final int subtotalCentavos;

  const CamporeeOrderSummaryItemModel({
    required this.productTitleSnapshot,
    required this.qty,
    required this.subtotalCentavos,
    this.optionLabelSnapshot,
  });

  factory CamporeeOrderSummaryItemModel.fromJson(Map<String, dynamic> json) {
    return CamporeeOrderSummaryItemModel(
      productTitleSnapshot: json['product_title_snapshot']?.toString() ?? '',
      optionLabelSnapshot: json['option_label_snapshot']?.toString(),
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      subtotalCentavos: (json['subtotal_centavos'] as num?)?.toInt() ?? 0,
    );
  }

  CamporeeOrderSummaryItem toEntity() => CamporeeOrderSummaryItem(
        productTitleSnapshot: productTitleSnapshot,
        optionLabelSnapshot: optionLabelSnapshot,
        qty: qty,
        subtotalCentavos: subtotalCentavos,
      );
}

/// Modelo de comprobante (GET /camporee-orders/:id/proof).
class CamporeeOrderProofModel {
  final String? url;
  final int? expiresIn;
  final String fileName;
  final String mimeType;
  final String status;
  final String? uploadedById;
  final DateTime createdAt;

  const CamporeeOrderProofModel({
    required this.fileName,
    required this.mimeType,
    required this.status,
    required this.createdAt,
    this.url,
    this.expiresIn,
    this.uploadedById,
  });

  factory CamporeeOrderProofModel.fromJson(Map<String, dynamic> json) {
    return CamporeeOrderProofModel(
      url: json['url']?.toString(),
      expiresIn: (json['expires_in'] as num?)?.toInt(),
      fileName: json['file_name']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SUBMITTED',
      uploadedById: json['uploaded_by_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  CamporeeOrderProof toEntity() => CamporeeOrderProof(
        url: url,
        expiresIn: expiresIn,
        fileName: fileName,
        mimeType: mimeType,
        status: CamporeeOrderProofStatusApi.fromApi(status),
        uploadedById: uploadedById,
        createdAt: createdAt,
      );
}

/// Modelo de pedido de mercancía (CamporeeOrderView).
class CamporeeOrderModel {
  final String orderId;
  final int? localCamporeeId;
  final int? unionCamporeeId;
  final String folioReference;
  final String status;
  final String currency;
  final int totalCentavos;
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool authorizedWithoutProof;
  final String distributionStatus;
  final List<CamporeeOrderLineModel> lines;
  final List<CamporeeOrderSummaryItemModel> summary;
  final String? bankName;
  final String? bankAccount;
  final String? bankClabe;
  final String? bankHolder;
  final String? cashInstructions;
  final String? extraNotes;

  const CamporeeOrderModel({
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

  factory CamporeeOrderModel.fromJson(Map<String, dynamic> json) {
    final lines = (json['lines'] as List<dynamic>? ?? [])
        .map((e) => CamporeeOrderLineModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return CamporeeOrderModel(
      orderId: json['camporee_order_id']?.toString() ?? '',
      localCamporeeId: (json['local_camporee_id'] as num?)?.toInt(),
      unionCamporeeId: (json['union_camporee_id'] as num?)?.toInt(),
      folioReference: json['folio_reference']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ISSUED',
      currency: json['currency']?.toString() ?? 'MXN',
      totalCentavos: (json['total_centavos'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      authorizedWithoutProof: json['authorized_without_proof'] == true,
      distributionStatus:
          json['distribution_status']?.toString() ?? 'NOT_STARTED',
      lines: lines,
      summary: (json['summary'] as List<dynamic>? ?? [])
          .map((e) =>
              CamporeeOrderSummaryItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      bankName: json['bank_name']?.toString(),
      bankAccount: json['bank_account']?.toString(),
      bankClabe: json['bank_clabe']?.toString(),
      bankHolder: json['bank_holder']?.toString(),
      cashInstructions: json['cash_instructions']?.toString(),
      extraNotes: json['extra_notes']?.toString(),
    );
  }

  CamporeeOrder toEntity() => CamporeeOrder(
        orderId: orderId,
        localCamporeeId: localCamporeeId,
        unionCamporeeId: unionCamporeeId,
        folioReference: folioReference,
        status: CamporeeOrderStatusApi.fromApi(status),
        currency: currency,
        totalCentavos: totalCentavos,
        expiresAt: expiresAt,
        createdAt: createdAt,
        authorizedWithoutProof: authorizedWithoutProof,
        distributionStatus:
            CamporeeOrderDistributionStatusApi.fromApi(distributionStatus),
        lines: lines.map((l) => l.toEntity()).toList(),
        summary: summary.map((s) => s.toEntity()).toList(),
        bankName: bankName,
        bankAccount: bankAccount,
        bankClabe: bankClabe,
        bankHolder: bankHolder,
        cashInstructions: cashInstructions,
        extraNotes: extraNotes,
      );
}
