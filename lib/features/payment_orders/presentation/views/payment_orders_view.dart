import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/entities/payment_order.dart';
import '../providers/payment_orders_providers.dart';
import '../widgets/payment_order_widgets.dart';

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
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text('payment_orders.list.title'.tr()),
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(paymentOrdersListProvider(filter)),
          child: ordersAsync.when(
            loading: () => const Center(child: SacLoading()),
            error: (error, _) => _ErrorState(
              message: error.toString().replaceFirst('Exception: ', ''),
              onRetry: () => ref.invalidate(paymentOrdersListProvider(filter)),
            ),
            data: (orders) => orders.isEmpty
                ? _EmptyState(c: c)
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _OrderCard(
                      order: orders[index],
                      onTap: () => context.push(
                        RouteNames.paymentOrderDetailPath(
                          orders[index].orderId,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final PaymentOrder order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final purposeLabel = order.purpose == PaymentOrderPurpose.insurance
        ? 'payment_orders.purpose.insurance'.tr()
        : 'payment_orders.purpose.camporee'.tr();

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.folioReference,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                  PaymentOrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  HugeIcon(
                    icon: order.purpose == PaymentOrderPurpose.insurance
                        ? HugeIcons.strokeRoundedShield01
                        : HugeIcons.strokeRoundedCampfire,
                    size: 14,
                    color: c.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    purposeLabel,
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedUserGroup,
                    size: 14,
                    color: c.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'payment_orders.list.beneficiaries_count'.tr(
                      namedArgs: {'count': order.lines.length.toString()},
                    ),
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    formatCentavos(order.totalCentavos, order.currency),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final SacColors c;

  const _EmptyState({required this.c});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        const SizedBox(height: 60),
        HugeIcon(
          icon: HugeIcons.strokeRoundedInvoice01,
          size: 48,
          color: c.textTertiary,
        ),
        const SizedBox(height: 14),
        Text(
          'payment_orders.list.empty'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.textSecondary),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        HugeIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          size: 42,
          color: AppColors.error,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: context.sac.textSecondary),
        ),
        const SizedBox(height: 14),
        SacButton.outline(text: 'common.retry'.tr(), onPressed: onRetry),
      ],
    );
  }
}
