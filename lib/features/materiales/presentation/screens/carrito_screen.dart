import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/cart_provider.dart';
import '../utils/money_format.dart';
import '../widgets/qty_stepper.dart';

/// Pantalla del carrito de materiales.
///
/// Muestra las líneas del carrito con posibilidad de editar cantidad o
/// eliminar cada una. El footer muestra el subtotal y el CTA para continuar
/// hacia la pantalla de resumen (PR12).
class CarritoScreen extends ConsumerWidget {
  const CarritoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito'),
        actions: [
          if (cart.lines.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, ref),
              child: const Text(
                'Vaciar',
                style: TextStyle(color: AppColors.error),
              ),
            ),
        ],
      ),
      body: cart.lines.isEmpty
          ? _EmptyCart(
              onBackToCatalog: () => context.pop(),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: cart.lines.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final line = cart.lines[index];
                return _CartLineItem(
                  line: line,
                  onQtyChanged: (qty) => ref
                      .read(cartProvider.notifier)
                      .updateQty(line.productId, line.variantOptionId, qty),
                  onRemove: () => ref
                      .read(cartProvider.notifier)
                      .removeLine(line.productId, line.variantOptionId),
                );
              },
            ),
      bottomSheet: cart.lines.isEmpty
          ? null
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: const Border(
                  top: BorderSide(color: AppColors.lightBorder),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        formatMxn(cart.subtotalCentavos),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      // PR12 defines the resumen route — placeholder push for now
                      onPressed: () => context.push(
                        '${RouteNames.homeMateriales}/resumen',
                      ),
                      child: const Text(
                        'Continuar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar carrito'),
        content: const Text(
            '¿Querés eliminar todos los productos del carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cartProvider.notifier).clear();
    }
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _CartLineItem extends StatelessWidget {
  final CartLine line;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;

  const _CartLineItem({
    required this.line,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail placeholder
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              line.productTitle.isNotEmpty
                  ? line.productTitle[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.productTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (line.variantLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    line.variantLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  formatMxn(line.priceSnapshotCentavos),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    QtyStepper(
                      value: line.qty,
                      min: 1,
                      max: 99,
                      onChanged: onQtyChanged,
                    ),
                    const Spacer(),
                    Text(
                      formatMxn(line.lineTotalCentavos),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.lightText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Remove button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.lightTextTertiary,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onBackToCatalog;

  const _EmptyCart({required this.onBackToCatalog});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 72,
            color: AppColors.lightTextTertiary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Tu carrito está vacío',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Agregá productos desde el catálogo',
            style: TextStyle(color: AppColors.lightTextTertiary),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Ir al catálogo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            onPressed: onBackToCatalog,
          ),
        ],
      ),
    );
  }
}
