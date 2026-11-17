import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

import '../../domain/entities/payment_order.dart';

/// Etiqueta i18n por estado de la orden.
String paymentOrderStatusLabel(PaymentOrderStatus status) {
  switch (status) {
    case PaymentOrderStatus.issued:
      return 'payment_orders.status.issued'.tr();
    case PaymentOrderStatus.proofSubmitted:
      return 'payment_orders.status.proof_submitted'.tr();
    case PaymentOrderStatus.approved:
      return 'payment_orders.status.approved'.tr();
    case PaymentOrderStatus.proofRejected:
      return 'payment_orders.status.proof_rejected'.tr();
    case PaymentOrderStatus.cancelled:
      return 'payment_orders.status.cancelled'.tr();
    case PaymentOrderStatus.expired:
      return 'payment_orders.status.expired'.tr();
  }
}

/// Badge compacto con el estado de una orden de pago.
class PaymentOrderStatusBadge extends StatelessWidget {
  final PaymentOrderStatus status;

  const PaymentOrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final label = paymentOrderStatusLabel(status);
    switch (status) {
      case PaymentOrderStatus.issued:
        return SacBadge.warning(
          label: label,
          icon: HugeIcons.strokeRoundedClock01,
        );
      case PaymentOrderStatus.proofSubmitted:
        return SacBadge.info(
          label: label,
          icon: HugeIcons.strokeRoundedUpload01,
        );
      case PaymentOrderStatus.approved:
        return SacBadge.success(
          label: label,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case PaymentOrderStatus.proofRejected:
      case PaymentOrderStatus.expired:
        return SacBadge.error(
          label: label,
          icon: HugeIcons.strokeRoundedAlert02,
        );
      case PaymentOrderStatus.cancelled:
        return SacBadge(
          label: label,
          icon: HugeIcons.strokeRoundedCancelCircle,
          variant: SacBadgeVariant.neutral,
        );
    }
  }
}
