import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/material_item.dart';
import '../../domain/entities/material_variant_option.dart';
import '../providers/cart_provider.dart';
import '../providers/product_detail_provider.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import '../widgets/qty_stepper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Pantalla de detalle de producto del catálogo de materiales.
class ProductDetailView extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailView({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends ConsumerState<ProductDetailView> {
  MaterialVariantOption? _selectedVariant;
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(productDetailProvider(widget.productId));
    final theme = Theme.of(context);
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SacTopBar(title: 'materials.product.title'.tr(), frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => itemAsync.when(
            loading: () => const Center(child: SacLoading()),
            error: (e, _) => SacErrorState(
              title: 'common.error_state.title'.tr(),
              message: userErrorMessage(e),
              onRetry: () =>
                  ref.invalidate(productDetailProvider(widget.productId)),
            ),
            data: (item) {
              // Determine stock limit for the stepper
              final maxQty = _selectedVariant?.stock ?? item.stock;

              return SingleChildScrollView(
                padding: SacTopBar.paddingBelowBar(
                    context, const EdgeInsets.all(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero area ──
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: SacAccent.of(context).surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.title.isNotEmpty
                            ? item.title[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize:
                              72, // ds-allow: placeholder initial sized to the image area
                          fontWeight: FontWeight.bold,
                          color: SacAccent.of(context).color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Title & SKU ──
                    Text(
                      item.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'materials.product.sku'.tr(namedArgs: {'sku': item.sku}),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Badges ──
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        SacBadge.info(label: item.category.label),
                        SacBadge.success(label: item.programa.label),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Description ──
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      Text(
                        item.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: c.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Price ──
                    Text(
                      SacMoney.fromCentavos(item.priceCentavos),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: SacAccent.of(context).color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Variant selector ──
                    if (item.hasVariants && item.variant != null) ...[
                      Text(
                        'materials.product.select_variant'.tr(
                          namedArgs: {'name': item.variant!.type.name},
                        ),
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
                                        _qty =
                                            option.stock.clamp(1, option.stock);
                                      }
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? SacAccent.of(context).color
                                    : outOfStock
                                        ? c.borderLight
                                        : c.surface,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusXS),
                                border: Border.all(
                                  color: selected
                                      ? SacAccent.of(context).color
                                      : c.border,
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
                                              ? c.textTertiary
                                              : c.text,
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
                                        fontSize: SacFontSize.caption,
                                        color: selected
                                            ? Colors.white70
                                            : c.textTertiary,
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
                          'materials.product.qty'.tr(),
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
                    SacButton.primary(
                      text: 'materials.product.add_to_cart'.tr(),
                      icon: HugeIcons.strokeRoundedShoppingCartAdd01,
                      onPressed:
                          maxQty > 0 ? () => _addToCart(item, context) : null,
                    ),

                    if (maxQty == 0) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'materials.product.out_of_stock'.tr(),
                          style: TextStyle(
                            color: c.onErrorContainer,
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
        ),
      ),
    );
  }

  void _addToCart(MaterialItem item, BuildContext context) {
    final router = GoRouter.maybeOf(context);
    ref.read(cartProvider.notifier).addLine(
          item,
          variantOption: _selectedVariant,
          qty: _qty,
        );

    SacSnackBar.show(
        context,
        'materials.product.added_snackbar'.tr(
          namedArgs: {'title': item.title},
        ),
        isSuccess: true,
        action: SnackBarAction(
          label: 'materials.product.view_cart'.tr(),
          textColor: Colors.white,
          // The action can fire after this page was popped, so use the
          // router captured now instead of this page's context.
          onPressed: () => router?.push(RouteNames.materialsCart),
        ));
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────
