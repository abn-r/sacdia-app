import '../../domain/entities/camporee_order.dart';

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

class CamporeeOrderProofDownloadModel {
  final String url;
  final int expiresIn;
  final String fileName;
  final String mimeType;
  final String status;
  final DateTime createdAt;

  const CamporeeOrderProofDownloadModel({
    required this.url,
    required this.expiresIn,
    required this.fileName,
    required this.mimeType,
    required this.status,
    required this.createdAt,
  });

  factory CamporeeOrderProofDownloadModel.fromJson(Map<String, dynamic> json) {
    return CamporeeOrderProofDownloadModel(
      url: json['url']?.toString() ?? '',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      fileName: json['file_name']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SUBMITTED',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  CamporeeOrderProofDownload toEntity() => CamporeeOrderProofDownload(
        url: url,
        expiresIn: expiresIn,
        fileName: fileName,
        mimeType: mimeType,
        status: status,
        createdAt: createdAt,
      );
}

class CamporeeOrderModel {
  final String orderId;
  final int localFieldId;
  final int clubId;
  final int clubSectionId;
  final int? localCamporeeId;
  final int? unionCamporeeId;
  final String folioReference;
  final String status;
  final String currency;
  final int totalCentavos;
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool authorizedWithoutProof;
  final String? authorizationReason;
  final DateTime? deliveredToSectionAt;
  final List<CamporeeOrderLineModel> lines;
  final List<CamporeeOrderSummaryItemModel> summary;
  final String distributionStatus;

  const CamporeeOrderModel({
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

  factory CamporeeOrderModel.fromJson(Map<String, dynamic> json) {
    final nestedOrder = json['order'];
    final root = nestedOrder is Map<String, dynamic> ? nestedOrder : json;
    return CamporeeOrderModel(
      orderId: root['camporee_order_id']?.toString() ?? '',
      localFieldId: (root['local_field_id'] as num?)?.toInt() ?? 0,
      clubId: (root['club_id'] as num?)?.toInt() ?? 0,
      clubSectionId: (root['club_section_id'] as num?)?.toInt() ?? 0,
      localCamporeeId: (root['local_camporee_id'] as num?)?.toInt(),
      unionCamporeeId: (root['union_camporee_id'] as num?)?.toInt(),
      folioReference: root['folio_reference']?.toString() ?? '',
      status: root['status']?.toString() ?? 'ISSUED',
      currency: root['currency']?.toString() ?? 'MXN',
      totalCentavos: (root['total_centavos'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.tryParse(root['expires_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: DateTime.tryParse(root['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      authorizedWithoutProof: root['authorized_without_proof'] == true,
      authorizationReason: root['authorization_reason']?.toString(),
      deliveredToSectionAt:
          DateTime.tryParse(root['delivered_to_section_at']?.toString() ?? ''),
      lines: (root['lines'] as List<dynamic>? ?? [])
          .map(
              (e) => CamporeeOrderLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: (root['summary'] as List<dynamic>? ?? [])
          .map(
            (e) => CamporeeOrderSummaryItemModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      distributionStatus:
          root['distribution_status']?.toString() ?? 'NOT_STARTED',
    );
  }

  CamporeeOrder toEntity() {
    final lineEntities = lines.map((l) => l.toEntity()).toList();
    return CamporeeOrder(
      orderId: orderId,
      localFieldId: localFieldId,
      clubId: clubId,
      clubSectionId: clubSectionId,
      localCamporeeId: localCamporeeId,
      unionCamporeeId: unionCamporeeId,
      folioReference: folioReference,
      status: CamporeeOrderStatusApi.fromApi(status),
      currency: currency,
      totalCentavos: totalCentavos,
      expiresAt: expiresAt,
      createdAt: createdAt,
      authorizedWithoutProof: authorizedWithoutProof,
      authorizationReason: authorizationReason,
      deliveredToSectionAt: deliveredToSectionAt,
      lines: lineEntities,
      summary: summary.map((s) => s.toEntity()).toList(),
      distributionStatus:
          CamporeeOrderDistributionStatusApi.fromApi(distributionStatus),
    );
  }
}
