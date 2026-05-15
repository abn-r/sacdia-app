import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/history_provider.dart';
import '../widgets/order_card.dart';

/// Pantalla de historial de pedidos del director.
///
/// Lista las órdenes propias del usuario ordenadas por fecha (más reciente
/// primero). Soporta pull-to-refresh y tiene estado vacío.
class OrderHistoryView extends ConsumerWidget {
  const OrderHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis pedidos'),
      ),
      body: historialAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
            onRefresh: () async => ref.invalidate(historyProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: ordenes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _EmptyHistorial extends StatelessWidget {
  final VoidCallback onGoCatalog;
  const _EmptyHistorial({required this.onGoCatalog});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedInvoice03,
              size: 72,
              color: AppColors.lightTextTertiary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no has realizado pedidos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Explorá el catálogo y hacé tu primer pedido.',
              style: TextStyle(color: AppColors.lightTextTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedStoreManagement01),
              label: const Text('Ir al catálogo'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.lightTextTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el historial',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.lightTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('Reintentar'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
