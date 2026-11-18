import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/material_delivery.dart';
import '../providers/cart_provider.dart';
import '../providers/config_provider.dart';
import '../providers/create_order_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/material_thumbs.dart';
import '../widgets/materials_rows.dart';
import '../widgets/qty_stepper.dart';

/// "Tu pedido": carrito y confirmación en una sola pantalla. Productos con su
/// contador, la entrega como dos opciones con lo que cuestan, notas, el total
/// y "Confirmar pedido" fijo abajo.
class CartView extends ConsumerStatefulWidget {
  const CartView({super.key});

  @override
  ConsumerState<CartView> createState() => _CartViewState();
}

class _CartViewState extends ConsumerState<CartView> {
  MaterialDelivery _delivery = MaterialDelivery.recoger;
  final _notesController = TextEditingController();

  /// True once the order was created. The cart is cleared right after, and the
  /// empty-cart state must not flash while the screen is leaving.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // The catalog's "added to cart · View cart" snackbar is moot once here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SacSnackBar.hideMessenger(ScaffoldMessenger.of(context));
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _removeWithUndo(CartLine line) {
    ref.read(cartProvider.notifier).removeLine(
          line.productId,
          line.variantOptionId,
        );
    SacSnackBar.show(
      context,
      'materials.cart.removed'.tr(namedArgs: {'title': line.productTitle}),
      action: SnackBarAction(
        label: 'materials.cart.undo'.tr(),
        textColor: SacAccent.of(context).onColor,
        onPressed: () => ref.read(cartProvider.notifier).restoreLine(line),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final c = context.sac;

    final body = cart.lines.isEmpty
        ? (_submitted
            ? const Center(child: SacLoading())
            : SacEmptyState(
                icon: HugeIcons.strokeRoundedShoppingCart01,
                title: 'materials.cart.empty_title'.tr(),
                body: 'materials.cart.empty_subtitle'.tr(),
                actionLabel: 'materials.cart.go_catalog'.tr(),
                onAction: () => context.canPop()
                    ? context.pop()
                    : context.go(RouteNames.materialsCatalog),
                actionIcon: HugeIcons.strokeRoundedArrowLeft01,
                actionVariant: SacButtonVariant.outline,
              ))
        : _OrderForm(
            delivery: _delivery,
            notesController: _notesController,
            onDelivery: (d) => setState(() => _delivery = d),
            onRemove: _removeWithUndo,
            onConfirm: _confirm,
          );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: 'materials.cart.title'.tr(),
        backgroundColor: c.canvas,
        frosted: true,
      ),
      body: SacFrostedVeil(child: Builder(builder: (_) => body)),
    );
  }

  /// Delivery the order is really sent with: the chosen one when the field
  /// offers it, else the first one it does.
  MaterialDelivery _effectiveDelivery(List<MaterialDelivery> offered) =>
      offered.isEmpty || offered.contains(_delivery)
          ? _delivery
          : offered.first;

  Future<void> _confirm() async {
    final cart = ref.read(cartProvider);
    if (cart.lines.isEmpty) return;
    final offered = ref.read(configProvider).value?.deliveryOptions ?? const [];
    final delivery = _effectiveDelivery(offered);

    // Resolve club_section_id from the active club context.
    // TODO(integration): without an active club context this is 0, which the
    // backend answers with 404; surface a proper error in that case.
    final clubCtx = await ref.read(clubContextProvider.future);
    final clubSectionId = clubCtx?.sectionId ?? 0;

    final lines = cart.lines
        .map((l) => (
              productId: l.productId,
              variantOptionId: l.variantOptionId,
              qty: l.qty,
            ))
        .toList();

    final notes = _notesController.text.trim();
    final result = await ref.read(createOrderProvider.notifier).confirm(
          clubSectionId: clubSectionId,
          lines: lines,
          delivery: delivery,
          notas: notes.isEmpty ? null : notes,
        );

    if (!mounted) return;

    result.fold(
      (failure) => SacSnackBar.show(context, failure.message, isError: true),
      (order) {
        // Capture everything that needs the context before leaving the screen.
        final router = GoRouter.of(context);
        final messenger = ScaffoldMessenger.of(context);
        final onColor = SacAccent.of(context).onColor;
        final folio = order.folioReferencia;
        final message = folio == null || folio.isEmpty
            ? 'materials.summary.order_sent'.tr()
            : 'materials.summary.order_sent_folio'
                .tr(namedArgs: {'folio': folio});
        final viewLabel = 'materials.summary.view_order'.tr();

        HapticFeedback.mediumImpact();
        setState(() => _submitted = true);
        ref.read(cartProvider.notifier).clear();
        ref.invalidate(historyProvider);

        // The cart was pushed on top of the catalog, which was pushed on top
        // of the list: leave both. A cold deep link has nothing below.
        if (router.canPop()) {
          router.pop();
          if (router.canPop()) router.pop();
        } else {
          router.go(RouteNames.homeMaterials);
        }

        SacSnackBar.showMessenger(
          messenger,
          message,
          isSuccess: true,
          action: SnackBarAction(
            label: viewLabel,
            textColor: onColor,
            onPressed: () {
              SacSnackBar.hideMessenger(messenger);
              router.push(RouteNames.materialsOrderDetail(order.routeKey));
            },
          ),
        );
      },
    );
  }
}

class _OrderForm extends ConsumerWidget {
  const _OrderForm({
    required this.delivery,
    required this.notesController,
    required this.onDelivery,
    required this.onRemove,
    required this.onConfirm,
  });

  final MaterialDelivery delivery;
  final TextEditingController notesController;
  final ValueChanged<MaterialDelivery> onDelivery;
  final ValueChanged<CartLine> onRemove;
  final VoidCallback onConfirm;

  static const double _thumb = 46;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final config = ref.watch(configProvider).value;
    final creating = ref.watch(createOrderProvider).isLoading;

    final offered = config?.deliveryOptions ?? const <MaterialDelivery>[];
    final options = offered.isEmpty
        ? const [MaterialDelivery.recoger, MaterialDelivery.envio]
        : offered;
    final selected = options.contains(delivery) ? delivery : options.first;
    final shipping = config?.envioCentavosDefault ?? 0;
    final shippingCentavos = selected == MaterialDelivery.envio ? shipping : 0;
    final total = cart.subtotalCentavos + shippingCentavos;
    final totalText = SacMoney.fromCentavos(total);

    return Stack(
      children: [
        ListView(
          padding: SacTopBar.paddingBelowBar(
            context,
            EdgeInsets.only(
              top: 0,
              bottom: SacFrostedFooter.height +
                  16 +
                  MediaQuery.paddingOf(context).bottom,
            ),
          ),
          children: [
            SacGroupedSection(
              key: const ValueKey('cart-products'),
              label: 'materials.cart.products'.tr(),
              count: cart.lines.length,
              dividerIndent: 14 + _thumb + 12,
              children: [
                for (final line in cart.lines)
                  _CartRow(
                    key: ValueKey(
                        'cart-${line.productId}-${line.variantOptionId}'),
                    line: line,
                    onQty: (qty) {
                      if (qty <= 0) {
                        onRemove(line);
                      } else {
                        ref.read(cartProvider.notifier).updateQty(
                              line.productId,
                              line.variantOptionId,
                              qty,
                            );
                      }
                    },
                  ),
              ],
            ),
            _Eyebrow('materials.summary.delivery_section'.tr()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final option in options) ...[
                    RadioOptionCard(
                      key: ValueKey('delivery-${option.name}'),
                      title: option == MaterialDelivery.recoger
                          ? 'materials.summary.pickup'.tr()
                          : 'materials.summary.ship'.tr(),
                      detail: option == MaterialDelivery.recoger
                          ? 'materials.summary.pickup_detail'.tr()
                          : 'materials.summary.ship_detail'.tr(
                              namedArgs: {
                                'cost': shipping == 0
                                    ? 'materials.summary.free'.tr()
                                    : SacMoney.fromCentavos(shipping),
                              },
                            ),
                      selected: option == selected,
                      onTap: () => onDelivery(option),
                    ),
                    if (option != options.last) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: SacTextField(
                controller: notesController,
                label: 'materials.summary.notes_label'.tr(),
                hint: 'materials.summary.notes_hint'.tr(),
                maxLines: 3,
              ),
            ),
            SacGroupedSection(
              key: const ValueKey('cart-totals'),
              label: 'materials.summary.total'.tr(),
              action: const SizedBox.shrink(),
              dividerIndent: 14,
              children: [
                MaterialsKvRow(
                  label: 'materials.cart.subtotal'.tr(),
                  value: SacMoney.fromCentavos(cart.subtotalCentavos),
                ),
                MaterialsKvRow(
                  label: 'materials.summary.shipping'.tr(),
                  value: shippingCentavos == 0
                      ? 'materials.summary.free'.tr()
                      : SacMoney.fromCentavos(shippingCentavos),
                ),
                MaterialsKvRow(
                  label: 'materials.summary.total'.tr(),
                  value: totalText,
                  emphasis: true,
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SacFrostedFooter(
            child: SacButton.primary(
              key: const ValueKey('cart-confirm'),
              text: 'materials.summary.confirm_total'
                  .tr(namedArgs: {'total': totalText}),
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              isLoading: creating,
              onPressed: creating ? null : onConfirm,
            ),
          ),
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: SacFontSize.labelSmall,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: context.sac.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({super.key, required this.line, required this.onQty});

  final CartLine line;
  final ValueChanged<int> onQty;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final price = SacMoney.fromCentavos(line.priceSnapshotCentavos);
    final detail =
        [if (line.variantLabel != null) line.variantLabel!, price].join(' · ');
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            ProductThumb(
              categorySlug: line.categorySlug,
              size: 46,
              radius: AppTheme.radiusSM,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.productTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textSecondary,
                      fontFeatures: SacMoney.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
            QtyStepper(value: line.qty, min: 0, max: 99, onChanged: onQty),
          ],
        ),
      ),
    );
  }
}
