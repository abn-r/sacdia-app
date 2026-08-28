import '../../domain/entities/payment_obligation.dart';

class PaymentObligationModel {
  final String source;
  final String sourceId;
  final String purpose;
  final String folio;
  final int totalCentavos;
  final String currency;
  final String status;
  final String actionRequired;
  final String? camporeeType;
  final int? camporeeId;
  final String? camporeeName;
  final DateTime createdAt;

  const PaymentObligationModel({
    required this.source,
    required this.sourceId,
    required this.purpose,
    required this.folio,
    required this.totalCentavos,
    required this.currency,
    required this.status,
    required this.actionRequired,
    required this.createdAt,
    this.camporeeType,
    this.camporeeId,
    this.camporeeName,
  });

  factory PaymentObligationModel.fromJson(Map<String, dynamic> json) {
    final camporee = json['camporee'];
    final camporeeMap = camporee is Map<String, dynamic> ? camporee : null;
    return PaymentObligationModel(
      source: json['source']?.toString() ?? 'FIELD_PAYMENT_ORDER',
      sourceId: json['source_id']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? 'INSURANCE',
      folio: json['folio']?.toString() ?? '',
      totalCentavos: (json['total_centavos'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'MXN',
      status: json['status']?.toString() ?? 'PAYMENT_DUE',
      actionRequired: json['action_required']?.toString() ?? 'UPLOAD_PROOF',
      camporeeType: camporeeMap?['type']?.toString(),
      camporeeId: (camporeeMap?['id'] as num?)?.toInt(),
      camporeeName: camporeeMap?['name']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  PaymentObligation toEntity() => PaymentObligation(
        source: PaymentObligationSourceApi.fromApi(source),
        sourceId: sourceId,
        purpose: PaymentObligationPurposeApi.fromApi(purpose),
        folio: folio,
        totalCentavos: totalCentavos,
        currency: currency,
        status: PaymentObligationStatusApi.fromApi(status),
        actionRequired: PaymentObligationActionApi.fromApi(actionRequired),
        camporee: camporeeId != null && camporeeType != null
            ? PaymentObligationCamporee(
                type: camporeeType!,
                id: camporeeId!,
                name: camporeeName ?? '',
              )
            : null,
        createdAt: createdAt,
      );
}
