import 'package:equatable/equatable.dart';

/// Fuente de una fila de Pagos pendientes. Nunca fusiona folios.
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
      case 'CAMPOREE_ORDER':
        return PaymentObligationSource.camporeeOrder;
      case 'MATERIAL_ORDER':
        return PaymentObligationSource.materialOrder;
      case 'FIELD_PAYMENT_ORDER':
      default:
        return PaymentObligationSource.fieldPaymentOrder;
    }
  }
}

enum PaymentObligationPurpose {
  camporeeMaterials,
  camporee,
  insurance,
  materials,
}

extension PaymentObligationPurposeApi on PaymentObligationPurpose {
  static PaymentObligationPurpose fromApi(String value) {
    switch (value) {
      case 'CAMPOREE_MATERIALS':
        return PaymentObligationPurpose.camporeeMaterials;
      case 'CAMPOREE':
        return PaymentObligationPurpose.camporee;
      case 'MATERIALS':
        return PaymentObligationPurpose.materials;
      case 'INSURANCE':
      default:
        return PaymentObligationPurpose.insurance;
    }
  }
}

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

class PaymentObligationCamporee extends Equatable {
  final String type;
  final int id;
  final String name;

  const PaymentObligationCamporee({
    required this.type,
    required this.id,
    required this.name,
  });

  @override
  List<Object?> get props => [type, id];
}

/// Obligación pendiente de lectura agregada (inscripción, materiales, pedidos).
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

  /// Ruta de detalle propietaria. Task 10 registra el GoRoute de pedidos.
  String get detailPath {
    switch (source) {
      case PaymentObligationSource.fieldPaymentOrder:
        return '/payment-orders/$sourceId';
      case PaymentObligationSource.materialOrder:
        return '/home/materials/order/$sourceId';
      case PaymentObligationSource.camporeeOrder:
        return '/camporee-orders/$sourceId';
    }
  }

  @override
  List<Object?> get props => [source, sourceId, folio];
}
