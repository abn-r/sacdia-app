import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

import '../../domain/entities/order.dart';
import '../providers/history_provider.dart';
import '../utils/order_presentation.dart';
import '../widgets/order_row.dart';

/// Entrada de "Pedidos": los pedidos del director agrupados por lo que hay
/// que hacer con ellos, y "Nuevo pedido" fijo abajo que abre el catálogo.
class OrderHistoryView extends ConsumerWidget {
  const OrderHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(historyProvider);
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: 'materials.history.title'.tr(),
        backgroundColor: c.canvas,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Stack(
          children: [
            Positioned.fill(
              child: Builder(
                builder: (context) => ordersAsync.when(
                  loading: () => const _OrdersSkeleton(),
                  error: (e, _) => _RefreshableBody(
                    onRefresh: () => _refresh(ref),
                    child: SacErrorState(
                      title: 'materials.history.error_title'.tr(),
                      message: userErrorMessage(e),
                      onRetry: () => ref.invalidate(historyProvider),
                    ),
                  ),
                  data: (orders) => orders.isEmpty
                      ? _RefreshableBody(
                          onRefresh: () => _refresh(ref),
                          child: SacEmptyState(
                            icon: HugeIcons.strokeRoundedInvoice03,
                            title: 'materials.history.empty_title'.tr(),
                            body: 'materials.history.empty_subtitle'.tr(),
                          ),
                        )
                      : _OrdersList(
                          orders: orders,
                          onRefresh: () => _refresh(ref),
                        ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SacFrostedFooter(
                child: SacButton.primary(
                  key: const ValueKey('orders-new'),
                  text: 'materials.history.new_order'.tr(),
                  icon: HugeIcons.strokeRoundedAdd01,
                  onPressed: () => context.push(RouteNames.materialsCatalog),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Invalidates [historyProvider] and waits for the new fetch so the
  /// indicator stays visible until the data arrives.
  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(historyProvider);
    try {
      await ref.read(historyProvider.future);
    } catch (_) {
      // The error state is rendered by the view; nothing to do here.
    }
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.orders, required this.onRefresh});

  final List<Order> orders;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final groups = groupOrders(orders);

    Widget group(String key, String labelKey, List<Order> list) {
      if (list.isEmpty) return const SizedBox.shrink();
      return SacGroupedSection(
        key: ValueKey(key),
        label: labelKey.tr(),
        dividerIndent: OrderRow.dividerIndent,
        children: [
          for (final order in list)
            OrderRow(
              key: ValueKey('order-${order.id}'),
              order: order,
              onTap: () =>
                  context.push(RouteNames.materialsOrderDetail(order.routeKey)),
            ),
        ],
      );
    }

    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: onRefresh,
      child: ListView(
        // Always scrollable: with a short list the default physics cannot
        // overscroll, so pull-to-refresh would never fire.
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: SacTopBar.paddingBelowBar(
          context,
          EdgeInsets.only(
            bottom: 24 +
                SacFrostedFooter.height -
                36 +
                MediaQuery.paddingOf(context).bottom,
          ),
        ),
        children: [
          group('orders-attention', 'materials.history.group_attention',
              groups.attention),
          group('orders-in-progress', 'materials.history.group_in_progress',
              groups.inProgress),
          group('orders-delivered', 'materials.history.group_delivered',
              groups.delivered),
          group('orders-cancelled', 'materials.history.group_cancelled',
              groups.cancelled),
        ],
      ),
    );
  }
}

/// Wraps a non-list body (empty / error) so pull-to-refresh still works.
class _RefreshableBody extends StatelessWidget {
  const _RefreshableBody({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - SacFrostedFooter.height,
            ),
            child: Padding(
              padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton with the real shape of the screen: a group of rows.
class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) {
    return SacShimmer(
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: SacTopBar.paddingBelowBar(
            context,
            const EdgeInsets.fromLTRB(20, 24, 20, 32),
          ),
          children: [
            for (var group = 0; group < 2; group++) ...[
              const SacSkeletonBox(width: 90, height: 10),
              const SizedBox(height: 12),
              for (var i = 0; i < (group == 0 ? 1 : 2); i++)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SacSkeletonBox(
                        width: 52,
                        height: 34,
                        radius: AppTheme.radiusXS,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SacSkeletonBox(width: 130, height: 12),
                            SizedBox(height: 8),
                            SacSkeletonBox(width: 100, height: 10),
                          ],
                        ),
                      ),
                      SacSkeletonBox(width: 56, height: 14),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}
