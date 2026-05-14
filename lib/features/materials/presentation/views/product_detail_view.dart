import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/material_item.dart';
import '../../domain/entities/material_variant_option.dart';
import '../providers/cart_provider.dart';
import '../providers/product_detail_provider.dart';
import '../utils/money_format.dart';
import '../widgets/qty_stepper.dart';

/// Pantalla de detalle de producto del catálogo de materiales.
class ProductDetailView extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailView({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailView> createState() =>
      _ProductDetailViewState();
}

class _ProductDetailViewState extends ConsumerState<ProductDetailView> {
  MaterialVariantOption? _selectedVariant;
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(productDetailProvider(widget.productId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del producto'),
      ),
      body: itemAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 48,
                  color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(productDetailProvider(widget.productId)),
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (item) {
          // Determine stock limit for the stepper
          final maxQty = _selectedVariant?.stock ?? item.stock;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero area ──
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.title.isNotEmpty ? item.title[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title & SKU ──
                Text(
                  item.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU: ${item.sku}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Badges ──
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Badge(label: item.category.label, color: AppColors.info),
                    _Badge(
                        label: item.programa.label, color: AppColors.secondary),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Description ──
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  Text(
                    item.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.lightTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Price ──
                Text(
                  formatMxn(item.priceCentavos),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Variant selector ──
                if (item.hasVariants && item.variant != null) ...[
                  Text(
                    'Selecciona ${item.variant!.type.name}:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.variant!.options.map((option) {
                      final selected = _selectedVariant?.id == option.id;
                      final outOfStock = option.stock == 0;
                      return GestureDetector(
                        onTap: outOfStock
                            ? null
                            : () {
                                setState(() {
                                  _selectedVariant = option;
                                  // Reset qty if new variant has less stock
                                  if (_qty > option.stock) {
                                    _qty = option.stock.clamp(1, option.stock);
                                  }
                                });
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : outOfStock
                                    ? AppColors.lightBorderLight
                                    : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                option.label,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : outOfStock
                                          ? AppColors.lightTextTertiary
                                          : AppColors.lightText,
                                  fontWeight: FontWeight.w500,
                                  decoration: outOfStock
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (!outOfStock)
                                Text(
                                  '${option.stock} disp.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: selected
                                        ? Colors.white70
                                        : AppColors.lightTextTertiary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Qty stepper ──
                Row(
                  children: [
                    Text(
                      'Cantidad:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    QtyStepper(
                      value: _qty,
                      min: 1,
                      max: maxQty.clamp(1, 100),
                      onChanged: (v) => setState(() => _qty = v),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Add to cart CTA ──
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedShoppingCartAdd01),
                    label: const Text('Agregar al carrito'),
                    style: FilledButton.styleFrom(
                      backgroundColor: maxQty > 0
                          ? AppColors.primary
                          : AppColors.lightTextTertiary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        maxQty > 0 ? () => _addToCart(item, context) : null,
                  ),
                ),

                if (maxQty == 0) ...[
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Producto agotado',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _addToCart(MaterialItem item, BuildContext context) {
    ref.read(cartProvider.notifier).addLine(
          item,
          variantOption: _selectedVariant,
          qty: _qty,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.title} agregado al carrito'),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Ver carrito',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            // Navigate back and let the cart icon guide the user
          },
        ),
      ),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
