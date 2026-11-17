import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/utils/icon_helper.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/payment_order.dart';
import '../../domain/utils/order_state_path.dart';

/// Everything the order screen says about where the order stands: the panel
/// (current state only) and the list of every state behind it.
class OrderStatePresentation {
  const OrderStatePresentation({
    required this.style,
    required this.title,
    required this.message,
    required this.stepLabel,
    required this.steps,
  });

  final SacStatusStyle style;
  final String title;
  final String message;
  final String stepLabel;
  final List<SacStateStep> steps;
}

SacStateKindLabels orderStateKindLabels() => SacStateKindLabels(
      done: tr('payment_orders.state.kind_done'),
      current: tr('payment_orders.state.kind_current'),
      rejected: tr('payment_orders.state.kind_rejected'),
      pending: tr('payment_orders.state.kind_pending'),
    );

String _shortDate(BuildContext context, DateTime date) =>
    DateFormat.MMMd(context.locale.toString()).format(date.toLocal());

/// [yearLabel] is the ecclesiastical year the insurance covers, when known.
OrderStatePresentation orderStatePresentation(
  BuildContext context,
  PaymentOrder order, {
  String? yearLabel,
}) {
  final isInsurance = order.purpose == PaymentOrderPurpose.insurance;
  final path = orderStatePath(order.status);
  final proofDate = order.latestProof?.createdAt;
  final hasProofDate =
      proofDate != null && proofDate.millisecondsSinceEpoch > 0;
  final year = yearLabel != null && yearLabel.isNotEmpty ? yearLabel : null;
  final total = SacMoney.fromCentavos(order.totalCentavos);

  String outcomeDetail() => isInsurance
      ? (year == null
          ? tr('payment_orders.state.outcome_year_generic')
          : tr('payment_orders.state.outcome_year', namedArgs: {'year': year}))
      : tr('payment_orders.state.outcome_camporee_detail');

  final steps = <SacStateStep>[
    for (final step in path.steps)
      SacStateStep(
        kind: _kind(step.kind),
        title: tr('payment_orders.state.step_${_key(step.id, isInsurance)}'),
        detail: switch (step.id) {
          OrderStepId.issued => _shortDate(context, order.createdAt),
          OrderStepId.pay => tr(
              'payment_orders.state.pay_before',
              namedArgs: {'date': _shortDate(context, order.expiresAt)},
            ),
          OrderStepId.proofSent =>
            hasProofDate ? _shortDate(context, proofDate) : null,
          OrderStepId.review => step.kind == OrderStepKind.current
              ? tr('payment_orders.state.review_hint')
              : null,
          OrderStepId.proofRejected => tr('payment_orders.state.rejected_hint'),
          OrderStepId.outcome => outcomeDetail(),
          OrderStepId.expired => _shortDate(context, order.expiresAt),
          _ => null,
        },
      ),
  ];

  final SacStatusKind kind;
  final HugeIconData? icon;
  final String key;
  Map<String, String> args = const {};
  switch (order.status) {
    case PaymentOrderStatus.issued:
      kind = SacStatusKind.review;
      icon = HugeIcons.strokeRoundedUpload01;
      key = 'issued';
      args = {'total': total, 'date': _shortDate(context, order.expiresAt)};
    case PaymentOrderStatus.proofSubmitted:
      kind = SacStatusKind.review;
      icon = HugeIcons.strokeRoundedClock01;
      key = !isInsurance
          ? 'proof_submitted_camporee'
          : (year == null
              ? 'proof_submitted_insurance_generic'
              : 'proof_submitted_insurance');
      args = {'year': year ?? ''};
    case PaymentOrderStatus.proofRejected:
      kind = SacStatusKind.rejected;
      icon = null;
      key = 'proof_rejected';
    case PaymentOrderStatus.approved:
      kind = SacStatusKind.validated;
      icon = null;
      key = !isInsurance
          ? 'approved_camporee'
          : (year == null
              ? 'approved_insurance_generic'
              : 'approved_insurance');
      args = {'year': year ?? ''};
    case PaymentOrderStatus.cancelled:
      kind = SacStatusKind.pending;
      icon = HugeIcons.strokeRoundedCancelCircle;
      key = 'cancelled';
    case PaymentOrderStatus.expired:
      kind = SacStatusKind.pending;
      icon = HugeIcons.strokeRoundedClock01;
      key = 'expired';
  }

  final title = tr('payment_orders.state.panel_$key.title');
  final message =
      tr('payment_orders.state.panel_$key.message', namedArgs: args);

  return OrderStatePresentation(
    style: SacStatusStyle.of(context, kind, label: title, icon: icon),
    title: title,
    message: message,
    stepLabel: tr(
      'payment_orders.state.step_of',
      namedArgs: {'current': '${path.current}', 'total': '${path.total}'},
    ),
    steps: steps,
  );
}

SacStateKind _kind(OrderStepKind kind) => switch (kind) {
      OrderStepKind.done => SacStateKind.done,
      OrderStepKind.current => SacStateKind.current,
      OrderStepKind.rejected => SacStateKind.rejected,
      OrderStepKind.pending => SacStateKind.pending,
    };

String _key(OrderStepId id, bool isInsurance) => switch (id) {
      OrderStepId.issued => 'issued',
      OrderStepId.pay => 'pay',
      OrderStepId.proofSent => 'proof_sent',
      OrderStepId.review => 'review',
      OrderStepId.proofRejected => 'proof_rejected',
      OrderStepId.approved => 'approved',
      OrderStepId.outcome =>
        isInsurance ? 'outcome_insurance' : 'outcome_camporee',
      OrderStepId.cancelled => 'cancelled',
      OrderStepId.expired => 'expired',
    };
