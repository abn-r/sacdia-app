import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

import '../../domain/entities/material_receipt_status.dart';
import '../../domain/entities/material_status.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/receipt.dart';
import '../providers/cancel_order_provider.dart';
import '../providers/history_provider.dart';
import '../providers/order_detail_provider.dart';
import '../providers/receipts_provider.dart';
import '../utils/order_presentation.dart';
import '../utils/receipt_file_name.dart';
import '../widgets/material_thumbs.dart';
import '../widgets/materials_rows.dart';
import '../widgets/order_action_sheets.dart';
import '../widgets/payment_sheet.dart';

/// Detalle de un pedido por folio o ID: solo el estado actual arriba (con
/// "Paso N de 4"; al tocarlo, la hoja con todos los estados), los productos y
/// el total. Una sola acción fija según el estado; cancelar vive en el menú ⋯.
class OrderReviewView extends ConsumerStatefulWidget {
  const OrderReviewView({
    super.key,
    required this.folioOrId,
    this.showPaymentOnOpen = false,
  });

  final String folioOrId;

  /// Opens the payment sheet once the order loads (the old payment link).
  final bool showPaymentOnOpen;

  @override
  ConsumerState<OrderReviewView> createState() => _OrderReviewViewState();
}

class _OrderReviewViewState extends ConsumerState<OrderReviewView> {
  bool _paymentShown = false;

  Future<void> _pay(Order order) async {
    final paid = await showPaymentSheet(context, order);
    if (paid == true && mounted) {
      context.push(RouteNames.materialsOrderReceipt(order.routeKey));
    }
  }

  Future<void> _openMenu(Order order) async {
    final folio = order.folioReferencia;
    final action = await showOrderMenuSheet(
      context,
      canCopyFolio: folio != null && folio.isNotEmpty,
      canCancel: order.isInReview,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case OrderMenuAction.copyFolio:
        await Clipboard.setData(ClipboardData(text: folio ?? ''));
        if (!mounted) return;
        SacSnackBar.show(context, 'materials.order.folio_copied'.tr());
      case OrderMenuAction.cancel:
        await _cancel(order);
    }
  }

  Future<void> _cancel(Order order) async {
    final reason = await showCancelOrderSheet(
      context,
      folio: order.folioReferencia ?? '',
    );
    if (reason == null || !mounted) return;

    final result = await ref
        .read(cancelOrderProvider.notifier)
        .cancel(folioOrId: order.routeKey, reason: reason);
    if (!mounted) return;

    result.fold(
      (failure) => SacSnackBar.show(context, failure.message, isError: true),
      (_) {
        ref.invalidate(orderDetailProvider(widget.folioOrId));
        // La lista de pedidos sigue montada debajo del detalle.
        ref.invalidate(historyProvider);
        SacSnackBar.show(context, 'materials.order.cancelled_snackbar'.tr());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.folioOrId));
    final cancelling = ref.watch(cancelOrderProvider).isLoading;
    final order = orderAsync.value;
    final c = context.sac;

    if (widget.showPaymentOnOpen &&
        !_paymentShown &&
        order != null &&
        order.status == MaterialStatus.aprobada) {
      _paymentShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pay(order);
      });
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: order?.folioReferencia ?? 'materials.order.title'.tr(),
        backgroundColor: c.canvas,
        frosted: true,
        actions: [
          if (order != null)
            SacPressable(
              listenOnly: true,
              child: IconButton(
                key: const ValueKey('order-more'),
                enableFeedback: false,
                tooltip: 'materials.order.more'.tr(),
                onPressed: cancelling ? null : () => _openMenu(order),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedMoreHorizontal,
                  size: 22,
                  color: c.text,
                ),
              ),
            ),
        ],
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => orderAsync.when(
            loading: () => const _DetailSkeleton(),
            error: (e, _) => SacErrorState(
              title: 'materials.order.load_error'.tr(),
              message: userErrorMessage(e),
              onRetry: () =>
                  ref.invalidate(orderDetailProvider(widget.folioOrId)),
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.all(24),
              ),
            ),
            data: (order) => _OrderBody(
              order: order,
              folioOrId: widget.folioOrId,
              onPay: () => _pay(order),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderBody extends ConsumerWidget {
  const _OrderBody({
    required this.order,
    required this.folioOrId,
    required this.onPay,
  });

  final Order order;
  final String folioOrId;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = order.routeKey;
    final needsReceipts = order.status != MaterialStatus.enRevision &&
        order.status != MaterialStatus.cancelada;
    final receiptsAsync =
        needsReceipts ? ref.watch(receiptsProvider(key)) : null;
    final receipts = receiptsAsync?.value ?? const <Receipt>[];

    // The footer depends on the receipts: wait for them instead of flashing
    // "Pagar" and then switching.
    if (order.status == MaterialStatus.aprobada &&
        receiptsAsync != null &&
        receiptsAsync.isLoading &&
        !receiptsAsync.hasValue) {
      return const _DetailSkeleton();
    }

    final state = orderStatePresentation(context, order, receipts: receipts);
    final attention = orderAttention(order, receipts: receipts);
    final total = SacMoney.fromCentavos(order.totalCentavos);
    final hasFooter = attention != OrderAttention.none;
    final rejectedReason = state.rejectedReason;

    Future<void> refresh() async {
      ref.invalidate(orderDetailProvider(folioOrId));
      if (needsReceipts) ref.invalidate(receiptsProvider(key));
      try {
        await ref.read(orderDetailProvider(folioOrId).future);
      } catch (_) {
        // The error state is rendered by the view.
      }
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: SacAccent.of(context).color,
          edgeOffset: SacTopBar.frostedInset(context),
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: SacTopBar.paddingBelowBar(
              context,
              EdgeInsets.only(
                top: 12,
                bottom: 32 +
                    (hasFooter
                        ? SacFrostedFooter.height -
                            40 +
                            MediaQuery.paddingOf(context).bottom
                        : 0),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SacStatePanel(
                  key: const ValueKey('order-state-panel'),
                  style: state.style,
                  title: state.title,
                  message: state.message,
                  stepLabel: state.stepLabel,
                  semanticsHint: 'materials.state.panel_hint'.tr(),
                  onTap: () => showSacStatesSheet(
                    context,
                    title: 'materials.state.sheet_title'.tr(),
                    subtitle: order.folioReferencia,
                    steps: state.steps,
                    kindLabels: orderStateKindLabels(),
                  ),
                ),
              ),
              if (rejectedReason != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _RejectionQuote(reason: rejectedReason),
                ),
              SacGroupedSection(
                key: const ValueKey('order-products'),
                label: 'materials.order.products'.tr(),
                count: order.lines.length,
                dividerIndent: 14 + 42 + 12,
                children: [
                  for (final line in order.lines)
                    _LineRow(
                      key: ValueKey('line-${line.id}'),
                      title: line.product.title,
                      detail:
                          '${line.qty} × ${SacMoney.fromCentavos(line.priceCentavos)}',
                      amount: SacMoney.fromCentavos(line.lineTotalCentavos),
                    ),
                ],
              ),
              SacGroupedSection(
                key: const ValueKey('order-totals'),
                label: 'materials.order.totals'.tr(),
                action: const SizedBox.shrink(),
                dividerIndent: 14,
                children: [
                  MaterialsKvRow(
                    label: 'materials.cart.subtotal'.tr(),
                    value: SacMoney.fromCentavos(order.subtotalCentavos),
                  ),
                  MaterialsKvRow(
                    label: 'materials.order.shipping'.tr(),
                    value: order.envioCentavos == 0
                        ? 'materials.summary.free'.tr()
                        : SacMoney.fromCentavos(order.envioCentavos),
                  ),
                  MaterialsKvRow(
                    label: 'materials.summary.total'.tr(),
                    value: total,
                    emphasis: true,
                  ),
                ],
              ),
              if (receipts.isNotEmpty)
                SacGroupedSection(
                  key: const ValueKey('order-receipts'),
                  label: 'materials.order.receipts'.tr(),
                  dividerIndent: 14 + 36 + 12,
                  children: [
                    for (var i = 0; i < receipts.length; i++)
                      _ReceiptRow(
                        key: ValueKey('receipt-${receipts[i].id}'),
                        receipt: receipts[i],
                        position: i + 1,
                        total: receipts.length,
                      ),
                  ],
                ),
            ],
          ),
        ),
        if (hasFooter)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SacFrostedFooter(
              child: attention == OrderAttention.pay
                  ? SacButton.primary(
                      key: const ValueKey('order-action'),
                      text:
                          'materials.order.pay'.tr(namedArgs: {'total': total}),
                      icon: HugeIcons.strokeRoundedMoney01,
                      onPressed: onPay,
                    )
                  : SacButton.primary(
                      key: const ValueKey('order-action'),
                      text: 'materials.order.upload_another'.tr(),
                      icon: HugeIcons.strokeRoundedFileUpload,
                      onPressed: () => context.push(
                        RouteNames.materialsOrderReceipt(key),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

/// The reviewer's reason, quoted in a white card under the error panel.
class _RejectionQuote extends StatelessWidget {
  const _RejectionQuote({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      container: true,
      label: '${'materials.order.reject_reason'.tr()}. $reason',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('order-reject-reason'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'materials.order.reject_reason'.tr().toUpperCase(),
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: c.onErrorContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '«$reason»',
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                height: 1.45,
                color: c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    super.key,
    required this.title,
    required this.detail,
    required this.amount,
  });

  final String title;
  final String detail;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      container: true,
      label: '$title, $detail, $amount',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              const ProductThumb(size: 42, radius: AppTheme.radiusSM),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: c.text,
                      ),
                    ),
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
              const SizedBox(width: 8),
              Text(
                amount,
                style: TextStyle(
                  fontSize: SacFontSize.titleMedium,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  fontFeatures: SacMoney.tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    super.key,
    required this.receipt,
    required this.position,
    required this.total,
  });

  final Receipt receipt;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final date = DateFormat.MMMd(context.locale.toString())
        .format(receipt.createdAt.toLocal());
    final detail =
        [date, SacMoney.fromCentavos(receipt.montoCentavos)].join(' · ');
    final badge = switch (receipt.status) {
      MaterialReceiptStatus.aprobado =>
        SacBadge.success(label: 'materials.order.receipt_approved'.tr()),
      MaterialReceiptStatus.rechazado =>
        SacBadge.error(label: 'materials.order.receipt_rejected'.tr()),
      MaterialReceiptStatus.pendiente =>
        SacBadge.info(label: 'materials.order.receipt_pending'.tr()),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              ),
              child: ExcludeSemantics(
                child: buildIcon(
                  HugeIcons.strokeRoundedFile01,
                  size: 18,
                  color: c.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receiptDisplayName(
                      storedName: receipt.fileName,
                      defaultLabel: 'materials.receipts.default_name'.tr(),
                      position: position,
                      total: total,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
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
            const SizedBox(width: 8),
            badge,
          ],
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SacShimmer(
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: SacTopBar.paddingBelowBar(
            context,
            const EdgeInsets.fromLTRB(20, 12, 20, 32),
          ),
          children: [
            const SacSkeletonBox(height: 96, radius: AppTheme.radiusMD),
            const SizedBox(height: 28),
            const SacSkeletonBox(width: 90, height: 10),
            const SizedBox(height: 12),
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SacSkeletonBox(
                      width: 42,
                      height: 42,
                      radius: AppTheme.radiusSM,
                    ),
                    SizedBox(width: 12),
                    Expanded(child: SacSkeletonBox(height: 12)),
                    SizedBox(width: 12),
                    SacSkeletonBox(width: 56, height: 14),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
