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

import '../providers/history_provider.dart';
import '../widgets/order_card.dart';

/// Historial de pedidos del director.
class OrderHistoryView extends ConsumerWidget {
  const OrderHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(historyProvider);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'materials.history.title'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
      ),
      body: historialAsync.when(
        loading: () => const _HistorySkeleton(),
        error: (e, _) => _ErrorBody(
          message: e.toString(),
          onRetry: () => ref.invalidate(historyProvider),
        ),
        data: (ordenes) {
          if (ordenes.isEmpty) {
            return _EmptyHistorial(
              onGoCatalog: () => context.go(RouteNames.homeMaterials),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(historyProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: ordenes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = ordenes[index];
                return OrderCard(
                  order: order,
                  onTap: () {
                    final key = order.folioReferencia ?? order.id;
                    context.push(RouteNames.materialsOrderDetail(key));
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: 104,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: c.border.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 72,
                  height: 22,
                  decoration: BoxDecoration(
                    color: c.border.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: 120,
              height: 11,
              decoration: BoxDecoration(
                color: c.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Spacer(),
            Container(
              width: 88,
              height: 14,
              decoration: BoxDecoration(
                color: c.border.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistorial extends StatelessWidget {
  final VoidCallback onGoCatalog;
  const _EmptyHistorial({required this.onGoCatalog});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedInvoice03,
              size: 64,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'materials.history.empty_title'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'materials.history.empty_subtitle'.tr(),
              style: TextStyle(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'materials.history.go_catalog'.tr(),
              icon: HugeIcons.strokeRoundedStoreManagement01,
              onPressed: onGoCatalog,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: c.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'materials.history.error_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: Text('common.retry'.tr()),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
