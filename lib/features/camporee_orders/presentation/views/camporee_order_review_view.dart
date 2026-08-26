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
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/providers/camporee_orders_providers.dart';
import 'package:sacdia_app/features/payment_orders/presentation/widgets/payment_order_widgets.dart';

/// Consolidado derivado + emisión. El cliente no envía montos.
class CamporeeOrderReviewView extends ConsumerWidget {
  final int camporeeId;
  final CamporeeKind camporeeType;

  const CamporeeOrderReviewView({
    super.key,
    required this.camporeeId,
    this.camporeeType = CamporeeKind.local,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = CamporeeOrdersScope(
      camporeeId: camporeeId,
      type: camporeeType,
    );
    final draft = ref.watch(camporeeOrderDraftProvider(scope));
    final c = context.sac;

    ref.listen(camporeeOrderDraftProvider(scope), (previous, next) {
      final order = next.issuedOrder;
      if (order != null && order != previous?.issuedOrder && context.mounted) {
        context.go(RouteNames.camporeeOrderDetailPath(order.orderId));
      }
    });

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text('camporee_orders.review.title'.tr()),
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: draft.lines.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'camporee_orders.review.empty'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: c.textSecondary),
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        if (draft.errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              draft.errorMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          'camporee_orders.review.summary_title'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SummaryCard(
                          items: deriveDraftSummary(draft.lines),
                          totalCentavos: draft.totalCentavos,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'camporee_orders.review.named_title'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final line in draft.lines) ...[
                          _NamedLineTile(line: line),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SacButton.primary(
                      key: const Key('camporee-order-submit'),
                      text: 'camporee_orders.review.submit'.tr(),
                      icon: HugeIcons.strokeRoundedInvoice03,
                      isLoading: draft.isSubmitting,
                      isEnabled: !draft.isSubmitting,
                      onPressed: draft.isSubmitting
                          ? null
                          : () => ref
                              .read(camporeeOrderDraftProvider(scope).notifier)
                              .submit(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<CamporeeOrderSummaryItem> items;
  final int totalCentavos;

  const _SummaryCard({required this.items, required this.totalCentavos});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.optionLabelSnapshot == null
                          ? '${item.productTitleSnapshot} × ${item.qty}'
                          : '${item.productTitleSnapshot} (${item.optionLabelSnapshot}) × ${item.qty}',
                      style: TextStyle(fontSize: 13.5, color: c.text),
                    ),
                  ),
                  Text(
                    formatCentavos(item.subtotalCentavos),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),
          Divider(color: c.border),
          Row(
            children: [
              Expanded(
                child: Text(
                  'camporee_orders.detail.total'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
              Text(
                formatCentavos(totalCentavos),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NamedLineTile extends StatelessWidget {
  final CamporeeOrderDraftLine line;

  const _NamedLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final option = line.optionLabel == null ? '' : ' · ${line.optionLabel}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Text(
        '${line.memberName} — ${line.productTitle}$option × ${line.qty}',
        style: TextStyle(fontSize: 13, color: c.text),
      ),
    );
  }
}
