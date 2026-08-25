import 'package:equatable/equatable.dart';

/// Origen de una obligación de pago pendiente (sin fusionar folios).
enum PaymentObligationSource {
  camporeeOrder,
  fieldPaymentOrder,
  materialOrder,
}

extension PaymentObligationSourceApi on PaymentObligationSource {
  String get apiValue {
    switch (this) {
      case PaymentObligationSource.camporeeOrder:
        return 'CAMPOREE_ORDER';
      case PaymentObligationSource.fieldPaymentOrder:
        return 'FIELD_PAYMENT_ORDER';
      case PaymentObligationSource.materialOrder:
        return 'MATERIAL_ORDER';
    }
  }

  static PaymentObligationSource fromApi(String value) {
    switch (value) {
      case 'FIELD_PAYMENT_ORDER':
        return PaymentObligationSource.fieldPaymentOrder;
      case 'MATERIAL_ORDER':
        return PaymentObligationSource.materialOrder;
      case 'CAMPOREE_ORDER':
      default:
        return PaymentObligationSource.camporeeOrder;
    }
  }
}

/// Propósito de negocio de la obligación.
enum PaymentObligationPurpose {
  camporeeMaterials,
  camporee,
  insurance,
  materials,
}

extension PaymentObligationPurposeApi on PaymentObligationPurpose {
  static PaymentObligationPurpose fromApi(String value) {
    switch (value) {
      case 'CAMPOREE':
        return PaymentObligationPurpose.camporee;
      case 'INSURANCE':
        return PaymentObligationPurpose.insurance;
      case 'MATERIALS':
        return PaymentObligationPurpose.materials;
      case 'CAMPOREE_MATERIALS':
      default:
        return PaymentObligationPurpose.camporeeMaterials;
    }
  }
}

/// Estado agregado de la obligación (no es el status de cada kernel).
enum PaymentObligationStatus {
  paymentDue,
  underReview,
  proofRejected,
  orderReview,
}

extension PaymentObligationStatusApi on PaymentObligationStatus {
  static PaymentObligationStatus fromApi(String value) {
    switch (value) {
      case 'UNDER_REVIEW':
        return PaymentObligationStatus.underReview;
      case 'PROOF_REJECTED':
        return PaymentObligationStatus.proofRejected;
      case 'ORDER_REVIEW':
        return PaymentObligationStatus.orderReview;
      case 'PAYMENT_DUE':
      default:
        return PaymentObligationStatus.paymentDue;
    }
  }
}

/// Acción que el cliente debe presentar.
enum PaymentObligationAction {
  uploadProof,
  waitReview,
  resubmitProof,
  waitApproval,
}

extension PaymentObligationActionApi on PaymentObligationAction {
  static PaymentObligationAction fromApi(String value) {
    switch (value) {
      case 'WAIT_REVIEW':
        return PaymentObligationAction.waitReview;
      case 'RESUBMIT_PROOF':
        return PaymentObligationAction.resubmitProof;
      case 'WAIT_APPROVAL':
        return PaymentObligationAction.waitApproval;
      case 'UPLOAD_PROOF':
      default:
        return PaymentObligationAction.uploadProof;
    }
  }
}

/// Camporee asociado a la obligación, si aplica.
class PaymentObligationCamporee extends Equatable {
  final String type;
  final int id;
  final String name;

  const PaymentObligationCamporee({
    required this.type,
    required this.id,
    required this.name,
  });

  bool get isUnion => type == 'union';

  @override
  List<Object?> get props => [type, id, name];
}

/// Ruta de detalle según `source`. No registra GoRoute (eso es Task 10).
String paymentObligationDetailRoute({
  required PaymentObligationSource source,
  required String sourceId,
}) {
  switch (source) {
    case PaymentObligationSource.fieldPaymentOrder:
      return '/payment-orders/$sourceId';
    case PaymentObligationSource.materialOrder:
      return '/home/materials/order/$sourceId';
    case PaymentObligationSource.camporeeOrder:
      return '/camporee-orders/$sourceId';
  }
}

/// Fila del read model de pagos pendientes. Dos folios = dos filas.
class PaymentObligation extends Equatable {
  final PaymentObligationSource source;
  final String sourceId;
  final PaymentObligationPurpose purpose;
  final String folio;
  final int totalCentavos;
  final String currency;
  final PaymentObligationStatus status;
  final PaymentObligationAction actionRequired;
  final PaymentObligationCamporee? camporee;
  final DateTime createdAt;

  const PaymentObligation({
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

  /// Deep link al flujo propietario de la fuente.
  String get detailRoute => paymentObligationDetailRoute(
        source: source,
        sourceId: sourceId,
      );

  @override
  List<Object?> get props => [source, sourceId, folio, status];
}
