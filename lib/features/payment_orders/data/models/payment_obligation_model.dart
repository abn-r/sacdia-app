import '../../../payment_orders/domain/entities/payment_obligation.dart';

/// Modelo del read model de obligaciones pendientes.
class PaymentObligationModel {
  final String source;
  final String sourceId;
  final String purpose;
  final String folio;
  final int totalCentavos;
  final String currency;
  final String status;
  final String actionRequired;
  final PaymentObligationCamporeeModel? camporee;
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
    this.camporee,
  });

  factory PaymentObligationModel.fromJson(Map<String, dynamic> json) {
    final camporeeJson = json['camporee'];
    return PaymentObligationModel(
      source: json['source']?.toString() ?? 'CAMPOREE_ORDER',
      sourceId: json['source_id']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? 'CAMPOREE_MATERIALS',
      folio: json['folio']?.toString() ?? '',
      totalCentavos: (json['total_centavos'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'MXN',
      status: json['status']?.toString() ?? 'PAYMENT_DUE',
      actionRequired: json['action_required']?.toString() ?? 'UPLOAD_PROOF',
      camporee: camporeeJson is Map<String, dynamic>
          ? PaymentObligationCamporeeModel.fromJson(camporeeJson)
          : null,
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
        camporee: camporee?.toEntity(),
        createdAt: createdAt,
      );
}

/// Modelo del camporee anidado en una obligación.
class PaymentObligationCamporeeModel {
  final String type;
  final int id;
  final String name;

  const PaymentObligationCamporeeModel({
    required this.type,
    required this.id,
    required this.name,
  });

  factory PaymentObligationCamporeeModel.fromJson(Map<String, dynamic> json) {
    return PaymentObligationCamporeeModel(
      type: json['type']?.toString() ?? 'local',
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }

  PaymentObligationCamporee toEntity() => PaymentObligationCamporee(
        type: type,
        id: id,
        name: name,
      );
}
