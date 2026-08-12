import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/payment_order.dart';

/// Formatea centavos como moneda (ej. 15000 → "$150.00").
String formatCentavos(int centavos, [String currency = 'MXN']) {
  final formatter = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
  return '${formatter.format(centavos / 100)} $currency';
}

/// Color semántico por estado de la orden.
Color paymentOrderStatusColor(PaymentOrderStatus status) {
  switch (status) {
    case PaymentOrderStatus.issued:
      return AppColors.accent;
    case PaymentOrderStatus.proofSubmitted:
      return AppColors.primary;
    case PaymentOrderStatus.approved:
      return AppColors.secondary;
    case PaymentOrderStatus.proofRejected:
    case PaymentOrderStatus.expired:
      return AppColors.error;
    case PaymentOrderStatus.cancelled:
      return Colors.grey;
  }
}

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
    final color = paymentOrderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        paymentOrderStatusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Línea de tiempo simple del ciclo de vida de la orden.
class PaymentOrderTimeline extends StatelessWidget {
  final PaymentOrder order;

  const PaymentOrderTimeline({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final steps = _steps();

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            step: steps[i],
            isLast: i == steps.length - 1,
            c: c,
          ),
      ],
    );
  }

  List<_TimelineStep> _steps() {
    final status = order.status;

    if (status == PaymentOrderStatus.cancelled) {
      return [
        _TimelineStep(
          label: 'payment_orders.timeline.issued'.tr(),
          done: true,
          color: AppColors.accent,
        ),
        _TimelineStep(
          label: 'payment_orders.status.cancelled'.tr(),
          done: true,
          color: Colors.grey,
        ),
      ];
    }
    if (status == PaymentOrderStatus.expired) {
      return [
        _TimelineStep(
          label: 'payment_orders.timeline.issued'.tr(),
          done: true,
          color: AppColors.accent,
        ),
        _TimelineStep(
          label: 'payment_orders.status.expired'.tr(),
          done: true,
          color: AppColors.error,
        ),
      ];
    }

    final proofRejected = status == PaymentOrderStatus.proofRejected;
    return [
      _TimelineStep(
        label: 'payment_orders.timeline.issued'.tr(),
        done: true,
        color: AppColors.accent,
      ),
      _TimelineStep(
        label: proofRejected
            ? 'payment_orders.status.proof_rejected'.tr()
            : 'payment_orders.timeline.proof_submitted'.tr(),
        done: status != PaymentOrderStatus.issued,
        color: proofRejected ? AppColors.error : AppColors.primary,
      ),
      _TimelineStep(
        label: 'payment_orders.timeline.approved'.tr(),
        done: status == PaymentOrderStatus.approved,
        color: AppColors.secondary,
      ),
    ];
  }
}

class _TimelineStep {
  final String label;
  final bool done;
  final Color color;

  const _TimelineStep({
    required this.label,
    required this.done,
    required this.color,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;
  final SacColors c;

  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.done ? step.color : Colors.transparent,
                  border: Border.all(
                    color: step.done ? step.color : c.border,
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: step.done
                        ? step.color.withValues(alpha: 0.4)
                        : c.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 0),
            child: Text(
              step.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: step.done ? FontWeight.w700 : FontWeight.w500,
                color: step.done ? c.text : c.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
