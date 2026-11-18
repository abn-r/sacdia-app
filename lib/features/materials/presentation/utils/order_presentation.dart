import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/material_delivery.dart';
import '../../domain/entities/material_receipt_status.dart';
import '../../domain/entities/material_status.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/receipt.dart';

/// What the director has to do next with an approved order.
enum OrderAttention {
  /// Nothing: the order is waiting on someone else, or it is over.
  none,

  /// Approved and no receipt yet: transfer the money and upload the receipt.
  pay,

  /// The last receipt was rejected: upload another.
  uploadAnother,
}

/// The newest receipt, or null when there is none.
Receipt? latestReceipt(List<Receipt> receipts) {
  if (receipts.isEmpty) return null;
  return receipts.reduce((a, b) => b.createdAt.isAfter(a.createdAt) ? b : a);
}

/// What is left to do for [order] given its [receipts] (the order's own list
/// when null).
OrderAttention orderAttention(Order order, {List<Receipt>? receipts}) {
  if (order.status != MaterialStatus.aprobada) return OrderAttention.none;
  final latest = latestReceipt(receipts ?? order.receipts);
  if (latest == null) return OrderAttention.pay;
  return latest.status == MaterialReceiptStatus.rechazado
      ? OrderAttention.uploadAnother
      : OrderAttention.none;
}

/// Orders split the way the list shows them.
class OrderGroups {
  const OrderGroups({
    required this.attention,
    required this.inProgress,
    required this.delivered,
    required this.cancelled,
  });

  /// Orders that need the user: pay, or upload another receipt.
  final List<Order> attention;

  /// Waiting on the campo local: review, receipt review, preparing.
  final List<Order> inProgress;
  final List<Order> delivered;
  final List<Order> cancelled;

  bool get isEmpty =>
      attention.isEmpty &&
      inProgress.isEmpty &&
      delivered.isEmpty &&
      cancelled.isEmpty;
}

/// Splits [orders] into the groups of the list, newest first in each.
OrderGroups groupOrders(List<Order> orders) {
  final sorted = [...orders]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final attention = <Order>[];
  final inProgress = <Order>[];
  final delivered = <Order>[];
  final cancelled = <Order>[];
  for (final order in sorted) {
    switch (order.status) {
      case MaterialStatus.cancelada:
        cancelled.add(order);
      case MaterialStatus.entregada:
        delivered.add(order);
      case MaterialStatus.enRevision:
      case MaterialStatus.pagada:
        inProgress.add(order);
      case MaterialStatus.aprobada:
        (orderAttention(order) == OrderAttention.none ? inProgress : attention)
            .add(order);
    }
  }
  return OrderGroups(
    attention: attention,
    inProgress: inProgress,
    delivered: delivered,
    cancelled: cancelled,
  );
}

/// Icon, color and words of a row of the list.
class OrderRowStyle {
  const OrderRowStyle({
    required this.icon,
    required this.color,
    required this.label,
  });

  final HugeIconData icon;
  final Color color;
  final String label;
}

OrderRowStyle orderRowStyle(BuildContext context, Order order) {
  final c = context.sac;
  switch (orderAttention(order)) {
    case OrderAttention.pay:
      return OrderRowStyle(
        icon: HugeIcons.strokeRoundedMoney01,
        color: c.onWarningContainer,
        label: 'materials.history.action_pay'.tr(
          namedArgs: {'total': SacMoney.fromCentavos(order.totalCentavos)},
        ),
      );
    case OrderAttention.uploadAnother:
      return OrderRowStyle(
        icon: HugeIcons.strokeRoundedAlertCircle,
        color: c.onErrorContainer,
        label: 'materials.order.upload_another'.tr(),
      );
    case OrderAttention.none:
      break;
  }
  switch (order.status) {
    case MaterialStatus.enRevision:
      return OrderRowStyle(
        icon: HugeIcons.strokeRoundedClock01,
        color: c.onInfoContainer,
        label: 'materials.state.review_short'.tr(),
      );
    case MaterialStatus.aprobada:
      return OrderRowStyle(
        icon: HugeIcons.strokeRoundedClock01,
        color: c.onInfoContainer,
        label: 'materials.state.reviewing_payment'.tr(),
      );
    case MaterialStatus.pagada:
      return OrderRowStyle(
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        color: c.onSuccessContainer,
        label: 'materials.state.paid'.tr(),
      );
    case MaterialStatus.entregada:
      return OrderRowStyle(
        icon: HugeIcons.strokeRoundedPackage,
        color: c.textSecondary,
        label: 'materials.state.delivered'.tr(),
      );
    case MaterialStatus.cancelada:
      return OrderRowStyle(
        icon: HugeIcons.strokeRoundedCancelCircle,
        color: c.onErrorContainer,
        label: 'materials.state.cancelled'.tr(),
      );
  }
}

/// Everything the detail screen says about where an order stands: the panel
/// (current state only) and the list of every state behind it.
class OrderStatePresentation {
  const OrderStatePresentation({
    required this.style,
    required this.title,
    required this.message,
    required this.steps,
    this.stepLabel,
    this.rejectedReason,
  });

  final SacStatusStyle style;
  final String title;
  final String message;

  /// "Paso 2 de 4"; null for a cancelled order.
  final String? stepLabel;
  final List<SacStateStep> steps;

  /// Why the last receipt was rejected, when it was and the reviewer said.
  final String? rejectedReason;
}

SacStateKindLabels orderStateKindLabels() => SacStateKindLabels(
      done: 'materials.state.kind_done'.tr(),
      current: 'materials.state.kind_current'.tr(),
      rejected: 'materials.state.kind_rejected'.tr(),
      pending: 'materials.state.kind_pending'.tr(),
    );

/// Step (1 to 4) the order is at, or null when it was cancelled.
int? orderStepNumber(MaterialStatus status) => switch (status) {
      MaterialStatus.enRevision => 1,
      MaterialStatus.aprobada => 2,
      MaterialStatus.pagada => 3,
      MaterialStatus.entregada => 4,
      MaterialStatus.cancelada => null,
    };

const int orderStepCount = 4;

String _shortDate(BuildContext context, DateTime date) =>
    DateFormat.MMMd(context.locale.toString()).format(date.toLocal());

/// [receipts] are the order's receipts (loaded apart from the order).
OrderStatePresentation orderStatePresentation(
  BuildContext context,
  Order order, {
  List<Receipt>? receipts,
}) {
  final c = context.sac;
  final list = receipts ?? order.receipts;
  final latest = latestReceipt(list);
  final attention = orderAttention(order, receipts: list);
  final total = SacMoney.fromCentavos(order.totalCentavos);
  final step = orderStepNumber(order.status);

  final dates = <MaterialStatus, DateTime?>{
    MaterialStatus.enRevision: order.createdAt,
    MaterialStatus.aprobada: order.approvedAt,
    MaterialStatus.pagada: order.paidAt,
    MaterialStatus.entregada: order.deliveredAt,
  };

  String? dateOf(MaterialStatus s) {
    final d = dates[s];
    return d == null ? null : _shortDate(context, d);
  }

  String join(List<String?> parts) =>
      parts.whereType<String>().where((p) => p.isNotEmpty).join(' · ');

  SacStateStep stepFor(MaterialStatus s, int number, String titleKey) {
    final kind = step == null
        ? (dates[s] != null ? SacStateKind.done : SacStateKind.pending)
        : number < step
            ? SacStateKind.done
            : number == step
                ? SacStateKind.current
                : SacStateKind.pending;
    final String? hint = switch (s) {
      MaterialStatus.enRevision => kind == SacStateKind.done
          ? 'materials.state.hint_review_done'.tr()
          : null,
      MaterialStatus.aprobada => kind == SacStateKind.current
          ? 'materials.state.hint_approved_current'.tr()
          : null,
      MaterialStatus.pagada => kind == SacStateKind.pending
          ? 'materials.state.hint_paid_next'.tr()
          : null,
      MaterialStatus.entregada => kind == SacStateKind.pending
          ? (order.delivery == MaterialDelivery.envio
              ? 'materials.state.hint_delivered_ship'.tr()
              : 'materials.state.hint_delivered_pickup'.tr())
          : null,
      MaterialStatus.cancelada => null,
    };
    return SacStateStep(
      kind: kind,
      title: titleKey.tr(),
      detail: switch (kind) {
        SacStateKind.pending => hint,
        _ => join([hint, dateOf(s)]),
      },
    );
  }

  final steps = <SacStateStep>[
    stepFor(MaterialStatus.enRevision, 1, 'materials.state.step_review'),
    stepFor(MaterialStatus.aprobada, 2, 'materials.state.step_approved'),
    stepFor(MaterialStatus.pagada, 3, 'materials.state.step_paid'),
    stepFor(MaterialStatus.entregada, 4, 'materials.state.step_delivered'),
  ];

  SacStatusStyle styled({
    required Color container,
    required Color onContainer,
    required Color solid,
    required HugeIconData icon,
    required SacStatusKind kind,
    required String label,
  }) =>
      SacStatusStyle(
        kind: kind,
        container: container,
        onContainer: onContainer,
        solid: solid,
        icon: icon,
        label: label,
      );

  String stepLabel() => 'materials.state.step_of'.tr(
        namedArgs: {'current': '${step ?? 0}', 'total': '$orderStepCount'},
      );

  switch (order.status) {
    case MaterialStatus.enRevision:
      return OrderStatePresentation(
        style: SacStatusStyle.of(
          context,
          SacStatusKind.review,
          label: 'materials.state.step_review'.tr(),
          icon: HugeIcons.strokeRoundedClock01,
        ),
        title: 'materials.state.step_review'.tr(),
        message: 'materials.state.review_message'.tr(),
        stepLabel: stepLabel(),
        steps: steps,
      );
    case MaterialStatus.aprobada:
      switch (attention) {
        case OrderAttention.pay:
          return OrderStatePresentation(
            style: styled(
              container: c.warningContainer,
              onContainer: c.onWarningContainer,
              solid: c.warning,
              icon: HugeIcons.strokeRoundedMoney01,
              kind: SacStatusKind.pending,
              label: 'materials.state.step_approved'.tr(),
            ),
            title: 'materials.state.step_approved'.tr(),
            message: 'materials.state.approved_message'
                .tr(namedArgs: {'total': total}),
            stepLabel: stepLabel(),
            steps: steps,
          );
        case OrderAttention.uploadAnother:
          final reason = latest?.rejectReason?.trim();
          return OrderStatePresentation(
            style: SacStatusStyle.of(
              context,
              SacStatusKind.rejected,
              label: 'materials.state.receipt_rejected'.tr(),
            ),
            title: 'materials.state.receipt_rejected'.tr(),
            message: 'materials.state.receipt_rejected_message'.tr(),
            stepLabel: stepLabel(),
            steps: steps,
            rejectedReason: reason == null || reason.isEmpty ? null : reason,
          );
        case OrderAttention.none:
          return OrderStatePresentation(
            style: SacStatusStyle.of(
              context,
              SacStatusKind.review,
              label: 'materials.state.reviewing_payment'.tr(),
              icon: HugeIcons.strokeRoundedClock01,
            ),
            title: 'materials.state.reviewing_payment'.tr(),
            message: 'materials.state.reviewing_payment_message'.tr(),
            stepLabel: stepLabel(),
            steps: steps,
          );
      }
    case MaterialStatus.pagada:
      return OrderStatePresentation(
        style: SacStatusStyle.of(
          context,
          SacStatusKind.validated,
          label: 'materials.state.step_paid'.tr(),
        ),
        title: 'materials.state.step_paid'.tr(),
        message: 'materials.state.paid_message'.tr(),
        stepLabel: stepLabel(),
        steps: steps,
      );
    case MaterialStatus.entregada:
      return OrderStatePresentation(
        style: SacStatusStyle.of(
          context,
          SacStatusKind.pending,
          label: 'materials.state.step_delivered'.tr(),
          icon: HugeIcons.strokeRoundedPackage,
        ),
        title: 'materials.state.step_delivered'.tr(),
        message: 'materials.state.delivered_message'.tr(),
        stepLabel: stepLabel(),
        steps: steps,
      );
    case MaterialStatus.cancelada:
      final reason = order.cancelReason?.trim();
      final reached = steps.where((s) => s.kind == SacStateKind.done).toList();
      final cancelledAt = order.cancelledAt;
      return OrderStatePresentation(
        style: SacStatusStyle.of(
          context,
          SacStatusKind.rejected,
          label: 'materials.state.cancelled'.tr(),
          icon: HugeIcons.strokeRoundedCancelCircle,
        ),
        title: 'materials.state.cancelled'.tr(),
        message: reason == null || reason.isEmpty
            ? 'materials.state.cancelled_message'.tr()
            : reason,
        steps: [
          ...reached,
          SacStateStep(
            kind: SacStateKind.rejected,
            title: 'materials.state.cancelled'.tr(),
            detail: join([
              if (cancelledAt != null) _shortDate(context, cancelledAt),
              reason,
            ]),
          ),
        ],
      );
  }
}
