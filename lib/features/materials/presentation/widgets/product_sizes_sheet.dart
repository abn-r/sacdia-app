import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/material_item.dart';
import '../../domain/entities/material_variant_option.dart';
import '../../domain/entities/material_variant_type.dart';
import '../providers/cart_provider.dart';
import 'material_thumbs.dart';
import 'qty_stepper.dart';

/// Stock at or below this is announced in the warning color ("Quedan 2").
const int kLowStockThreshold = 3;

/// Opens the product sheet over the catalog: image, name, price and one
/// stepper per size. "Agregar" adds every size in one go.
Future<void> showProductSheet(BuildContext context, MaterialItem item) {
  final router = GoRouter.maybeOf(context);
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProductSizesSheet(item: item, router: router),
  );
}

class ProductSizesSheet extends ConsumerStatefulWidget {
  const ProductSizesSheet({super.key, required this.item, this.router});

  final MaterialItem item;

  /// Captured before the sheet opens: the "Ver carrito" action can fire after
  /// the sheet is gone.
  final GoRouter? router;

  @override
  ConsumerState<ProductSizesSheet> createState() => _ProductSizesSheetState();
}

class _ProductSizesSheetState extends ConsumerState<ProductSizesSheet> {
  /// Quantity per size option id; the product id when it has no sizes.
  final Map<String, int> _qty = {};

  MaterialItem get _item => widget.item;

  List<MaterialVariantOption> get _options =>
      _item.variant?.options ?? const [];

  int get _units => _qty.values.fold(0, (a, b) => a + b);
  int get _totalCentavos => _units * _item.priceCentavos;

  void _set(String key, int value) => setState(() => _qty[key] = value);

  void _add() {
    final cart = ref.read(cartProvider.notifier);
    if (_item.hasVariants) {
      for (final option in _options) {
        final qty = _qty[option.id] ?? 0;
        if (qty > 0) cart.addLine(_item, variantOption: option, qty: qty);
      }
    } else {
      final qty = _qty[_item.id] ?? 0;
      if (qty > 0) cart.addLine(_item, qty: qty);
    }
    HapticFeedback.lightImpact();
    final router = widget.router;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    SacSnackBar.showMessenger(
      messenger,
      'materials.product.added_snackbar'.tr(namedArgs: {'title': _item.title}),
      isSuccess: true,
      action: SnackBarAction(
        label: 'materials.product.view_cart'.tr(),
        textColor: SacAccent.of(context).onColor,
        onPressed: () => router?.push(RouteNames.materialsCart),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final item = _item;
    final isColor = item.variant?.type == MaterialVariantType.color;
    final subtitle = [item.category.label, item.programa.label]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SacSheetGrabber(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: Row(
                        children: [
                          ProductThumb(
                            categorySlug: item.category.slug,
                            size: 76,
                            radius: AppTheme.radiusMD,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: SacFontSize.titleLarge,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                      color: c.text,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  SacMoney.fromCentavos(item.priceCentavos),
                                  style: TextStyle(
                                    fontSize: SacFontSize.titleMedium,
                                    fontWeight: FontWeight.w700,
                                    color: SacAccent.of(context).color,
                                    fontFeatures: SacMoney.tabularFigures,
                                  ),
                                ),
                                if (subtitle.isNotEmpty)
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: SacFontSize.bodySmall,
                                      color: c.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.hasVariants)
                      SacGroupedSection(
                        key: const ValueKey('product-sizes'),
                        label: (isColor
                                ? 'materials.product.colors'
                                : 'materials.product.sizes')
                            .tr(),
                        count: _options.length,
                        dividerIndent: 14,
                        children: [
                          for (final option in _options)
                            _StockRow(
                              key: ValueKey('size-${option.id}'),
                              title: (isColor
                                      ? 'materials.product.option_color'
                                      : 'materials.product.option_size')
                                  .tr(namedArgs: {'label': option.label}),
                              stock: option.stock,
                              value: _qty[option.id] ?? 0,
                              onChanged: (v) => _set(option.id, v),
                            ),
                        ],
                      )
                    else
                      SacGroupedSection(
                        key: const ValueKey('product-single'),
                        label: 'materials.product.qty'.tr(),
                        action: const SizedBox.shrink(),
                        dividerIndent: 14,
                        children: [
                          _StockRow(
                            key: const ValueKey('size-single'),
                            title: 'materials.product.pieces'.tr(),
                            stock: item.stock,
                            value: _qty[item.id] ?? 0,
                            onChanged: (v) => _set(item.id, v),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SacButton.primary(
                key: const ValueKey('product-add'),
                text: _units == 0
                    ? 'materials.product.add_none'.tr()
                    : 'materials.product.add_n'.tr(namedArgs: {
                        'count': '$_units',
                        'total': SacMoney.fromCentavos(_totalCentavos),
                      }),
                icon: HugeIcons.strokeRoundedShoppingCartAdd01,
                isEnabled: _units > 0,
                onPressed: _add,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A size (or the single piece): name, how many are left, and a stepper.
/// Sold out: muted, "Agotada", no stepper.
class _StockRow extends StatelessWidget {
  const _StockRow({
    super.key,
    required this.title,
    required this.stock,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final int stock;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final soldOut = stock <= 0;
    final low = !soldOut && stock <= kLowStockThreshold;
    final detail = soldOut
        ? 'materials.product.sold_out'.tr()
        : 'materials.product.left'.tr(namedArgs: {'count': '$stock'});

    return Semantics(
      container: true,
      label: '$title, $detail',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: soldOut ? 0.55 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: SacFontSize.titleMedium,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        Text(
                          detail,
                          style: TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            fontWeight: low ? FontWeight.w600 : FontWeight.w400,
                            color: low ? c.onWarningContainer : c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (soldOut)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text('—', style: TextStyle(color: c.textTertiary)),
                )
              else
                QtyStepper(
                  value: value,
                  min: 0,
                  max: stock,
                  onChanged: onChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
