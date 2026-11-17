import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/utils/back_or_home.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../../camporee_orders/presentation/providers/camporee_orders_providers.dart';
import '../../domain/entities/payment_obligation.dart';
import '../../domain/entities/payment_order.dart';
import '../providers/payment_orders_providers.dart';
import '../widgets/payment_order_widgets.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Lista de órdenes de pago del club/sección del usuario.
///
/// Con [camporeeId] muestra solo las órdenes de ese camporee; con [purpose]
/// filtra por propósito.
class PaymentOrdersView extends ConsumerWidget {
  final PaymentOrderPurpose? purpose;
  final int? camporeeId;

  const PaymentOrdersView({super.key, this.purpose, this.camporeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter =
        PaymentOrdersFilter(purpose: purpose, camporeeId: camporeeId);
    final ordersAsync = ref.watch(paymentOrdersListProvider(filter));
    final obligationsAsync = ref.watch(pendingPaymentObligationsProvider);
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: 'payment_orders.list.title'.tr(),
        backgroundColor: c.canvas,
        frosted: true,
        onBack: () => backOrHome(context),
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => RefreshIndicator(
            edgeOffset: SacTopBar.frostedInset(context),
            onRefresh: () async {
              ref.invalidate(paymentOrdersListProvider(filter));
              ref.invalidate(pendingPaymentObligationsProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.only(bottom: 32),
              ),
              children: [
                // Insurance orders are the whole story of the insurance
                // module; the camporee obligations belong to the camporee.
                if (purpose != PaymentOrderPurpose.insurance)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: _PendingObligationsSection(async: obligationsAsync),
                  ),
                ordersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: SacLoading()),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SacErrorState.inline(
                      message: userErrorMessage(error),
                      onRetry: () =>
                          ref.invalidate(paymentOrdersListProvider(filter)),
                    ),
                  ),
                  data: (orders) => orders.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: SacEmptyState(
                            icon: HugeIcons.strokeRoundedInvoice01,
                            title: 'payment_orders.list.empty'.tr(),
                          ),
                        )
                      : _GroupedOrders(orders: orders),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Por atender (hay que subir un recibo) / En revisión / Cerradas.
class _GroupedOrders extends StatelessWidget {
  const _GroupedOrders({required this.orders});

  final List<PaymentOrder> orders;

  @override
  Widget build(BuildContext context) {
    bool isAttend(PaymentOrder o) =>
        o.status == PaymentOrderStatus.issued ||
        o.status == PaymentOrderStatus.proofRejected;
    final attend = orders.where(isAttend).toList();
    final review = orders
        .where((o) => o.status == PaymentOrderStatus.proofSubmitted)
        .toList();
    final closed = orders
        .where((o) =>
            !isAttend(o) && o.status != PaymentOrderStatus.proofSubmitted)
        .toList();

    Widget group(String key, String label, List<PaymentOrder> list) =>
        list.isEmpty
            ? const SizedBox.shrink()
            : SacGroupedSection(
                key: ValueKey('payment-orders-$key'),
                label: label,
                children: [for (final o in list) _OrderRow(order: o)],
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        group('attend', 'payment_orders.list.group_attend'.tr(), attend),
        group('review', 'payment_orders.list.group_review'.tr(), review),
        group('closed', 'payment_orders.list.group_closed'.tr(), closed),
      ],
    );
  }
}

class _PendingObligationsSection extends StatelessWidget {
  final AsyncValue<List<PaymentObligation>> async;

  const _PendingObligationsSection({required this.async});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'camporee_orders.pending.title'.tr(),
          style: TextStyle(
            fontSize: SacFontSize.titleMedium,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: SacLoading()),
          ),
          error: (error, _) => Text(
            camporeeOrdersErrorMessage(error),
            style: TextStyle(
                fontSize: SacFontSize.bodyMedium, color: c.textSecondary),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'camporee_orders.pending.empty'.tr(),
                  style: TextStyle(
                      fontSize: SacFontSize.bodyMedium, color: c.textSecondary),
                ),
              );
            }
            return Column(
              children: [
                for (final obligation in items) ...[
                  _ObligationCard(
                    obligation: obligation,
                    onTap: () => context.go(obligation.detailPath),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ObligationCard extends StatelessWidget {
  final PaymentObligation obligation;
  final VoidCallback onTap;

  const _ObligationCard({required this.obligation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: SacInkWell(
        key: Key('pending-obligation-${obligation.sourceId}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      obligation.folio,
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _obligationPurposeLabel(obligation.purpose),
                      style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                SacMoney.fromCentavos(obligation.totalCentavos),
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _obligationPurposeLabel(PaymentObligationPurpose purpose) {
    switch (purpose) {
      case PaymentObligationPurpose.camporeeMaterials:
        return 'camporee_orders.pending.purpose.camporee_materials'.tr();
      case PaymentObligationPurpose.camporeeSupplies:
        return 'camporee_supplies.cta.label'.tr();
      case PaymentObligationPurpose.camporee:
        return 'camporee_orders.pending.purpose.camporee'.tr();
      case PaymentObligationPurpose.materials:
        return 'camporee_orders.pending.purpose.materials'.tr();
      case PaymentObligationPurpose.insurance:
        return 'camporee_orders.pending.purpose.insurance'.tr();
    }
  }
}

class _OrderRow extends StatelessWidget {
  final PaymentOrder order;

  const _OrderRow({required this.order});

  SacStatusStyle _style(BuildContext context) {
    final label = paymentOrderStatusLabel(order.status);
    switch (order.status) {
      case PaymentOrderStatus.issued:
        return SacStatusStyle.of(
          context,
          SacStatusKind.review,
          label: label,
          icon: HugeIcons.strokeRoundedUpload01,
        );
      case PaymentOrderStatus.proofSubmitted:
        return SacStatusStyle.of(
          context,
          SacStatusKind.review,
          label: label,
          icon: HugeIcons.strokeRoundedClock01,
        );
      case PaymentOrderStatus.proofRejected:
        return SacStatusStyle.of(context, SacStatusKind.rejected, label: label);
      case PaymentOrderStatus.approved:
        return SacStatusStyle.of(
          context,
          SacStatusKind.validated,
          label: label,
          icon: HugeIcons.strokeRoundedTick02,
        );
      case PaymentOrderStatus.cancelled:
        return SacStatusStyle.of(
          context,
          SacStatusKind.pending,
          label: label,
          icon: HugeIcons.strokeRoundedCancelCircle,
        );
      case PaymentOrderStatus.expired:
        return SacStatusStyle.of(
          context,
          SacStatusKind.pending,
          label: label,
          icon: HugeIcons.strokeRoundedClock01,
        );
    }
  }

  String _detail(BuildContext context) {
    final people =
        'payment_orders.list.people_count'.plural(order.lines.length);
    final parts = [people, SacMoney.fromCentavos(order.totalCentavos)];
    if (order.status == PaymentOrderStatus.issued) {
      parts.add(
        'payment_orders.list.expires'.tr(
          namedArgs: {
            'date': DateFormat.MMMd(context.locale.toString())
                .format(order.expiresAt.toLocal()),
          },
        ),
      );
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacStatusRow(
      key: ValueKey('payment-order-${order.orderId}'),
      style: _style(context),
      title: order.folioReference,
      detail: _detail(context),
      onTap: () => context.push(
        RouteNames.paymentOrderDetailPath(order.orderId),
      ),
      trailing: ConstrainedBox(
        // The title wins at large text sizes: the badge wraps inside this.
        constraints: const BoxConstraints(maxWidth: 140),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: PaymentOrderStatusBadge(status: order.status)),
            const SizedBox(width: 4),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 18,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
