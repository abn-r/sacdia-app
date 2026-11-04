import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_expansion_tile.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_offering.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/providers/camporee_orders_providers.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';

/// Captura nominada: roster del camporee + artículo/talla por persona.
class CamporeeMemberOrderView extends ConsumerWidget {
  final int camporeeId;
  final CamporeeKind camporeeType;

  const CamporeeMemberOrderView({
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
    final rosterAsync = ref.watch(camporeeOrderRosterProvider(camporeeId));
    final offeringsAsync = ref.watch(camporeeOrderOfferingsProvider(scope));
    final draft = ref.watch(camporeeOrderDraftProvider(scope));
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'camporee_orders.capture.title'.tr(),
          backgroundColor: c.surface,
          foregroundColor: c.text,
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: rosterAsync.when(
              loading: () => const Center(child: SacLoading()),
              error: (error, _) => SacErrorState(
                title: '',
                message: camporeeOrdersErrorMessage(error),
                onRetry: () =>
                    ref.invalidate(camporeeOrderRosterProvider(camporeeId)),
              ),
              data: (roster) {
                if (roster.isEmpty) {
                  return SacEmptyState(
                    icon: HugeIcons.strokeRoundedUserGroup,
                    title: 'camporee_orders.capture.empty_roster'.tr(),
                    actionLabel: 'common.retry'.tr(),
                    actionIcon: HugeIcons.strokeRoundedRefresh,
                    actionVariant: SacButtonVariant.outline,
                    onAction: () =>
                        ref.invalidate(camporeeOrderRosterProvider(camporeeId)),
                  );
                }
                return offeringsAsync.when(
                  loading: () => const Center(child: SacLoading()),
                  error: (error, _) => SacErrorState(
                    title: '',
                    message: camporeeOrdersErrorMessage(error),
                    onRetry: () =>
                        ref.invalidate(camporeeOrderOfferingsProvider(scope)),
                  ),
                  data: (catalog) {
                    final window =
                        evaluateCamporeeOrdersWindow(catalog.settings);
                    if (window != CamporeeOrdersWindow.open) {
                      return SacEmptyState(
                        icon: HugeIcons.strokeRoundedCalendar03,
                        title: window == CamporeeOrdersWindow.notOpen
                            ? 'camporee_orders.catalog.not_open'.tr()
                            : 'camporee_orders.catalog.closed'.tr(),
                      );
                    }
                    final offerings = catalog.items
                        .where((item) => item.active)
                        .toList()
                      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                    if (offerings.isEmpty) {
                      return SacEmptyState(
                        icon: HugeIcons.strokeRoundedShoppingBag01,
                        title: 'camporee_orders.catalog.offerings_empty'.tr(),
                      );
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: SacTopBar.paddingBelowBar(context,
                                const EdgeInsets.fromLTRB(16, 12, 16, 20)),
                            itemCount: roster.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final member = roster[index];
                              return _MemberCaptureCard(
                                member: member,
                                offerings: offerings,
                                lines: draft.lines
                                    .where(
                                      (line) =>
                                          line.camporeeMemberId ==
                                          member.camporeeMemberId,
                                    )
                                    .toList(),
                                onChanged: (line) => ref
                                    .read(camporeeOrderDraftProvider(scope)
                                        .notifier)
                                    .upsertLine(line),
                              );
                            },
                          ),
                        ),
                        _CaptureFooter(
                          lineCount: draft.lines.length,
                          totalCentavos: draft.totalCentavos,
                          onContinue: draft.lines.isEmpty
                              ? null
                              : () => context.push(
                                    RouteNames.camporeeOrdersReviewPath(
                                      camporeeId,
                                      type: scope.typeQuery,
                                    ),
                                  ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberCaptureCard extends StatelessWidget {
  final CamporeeMember member;
  final List<CamporeeOrderOffering> offerings;
  final List<CamporeeOrderDraftLine> lines;
  final ValueChanged<CamporeeOrderDraftLine> onChanged;

  const _MemberCaptureCard({
    required this.member,
    required this.offerings,
    required this.lines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final name = member.userName?.trim().isNotEmpty == true
        ? member.userName!
        : (member.userEmail ?? '#${member.camporeeMemberId}');

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: SacExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(
            name,
            style: TextStyle(
              fontSize: SacFontSize.titleSmall,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          subtitle: lines.isEmpty
              ? null
              : Text(
                  'camporee_orders.capture.lines_count'.tr(
                    namedArgs: {'count': lines.length.toString()},
                  ),
                  style: TextStyle(
                      fontSize: SacFontSize.bodySmall, color: c.textSecondary),
                ),
          children: [
            for (final offering in offerings)
              _OfferingCaptureRow(
                member: member,
                memberName: name,
                offering: offering,
                lines: lines,
                onChanged: onChanged,
              ),
          ],
        ),
      ),
    );
  }
}

class _OfferingCaptureRow extends StatelessWidget {
  final CamporeeMember member;
  final String memberName;
  final CamporeeOrderOffering offering;
  final List<CamporeeOrderDraftLine> lines;
  final ValueChanged<CamporeeOrderDraftLine> onChanged;

  const _OfferingCaptureRow({
    required this.member,
    required this.memberName,
    required this.offering,
    required this.lines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final options = offering.product.options
        .where((option) => option.active)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final requiresOption = offering.requiresOption;

    if (requiresOption && options.isEmpty) {
      return const SizedBox.shrink();
    }

    if (!requiresOption) {
      CamporeeOrderDraftLine? current;
      for (final line in lines) {
        if (line.offeringId == offering.offeringId && line.optionId == null) {
          current = line;
          break;
        }
      }
      return _QtyRow(
        title: offering.product.title,
        priceLabel: SacMoney.fromCentavos(offering.priceCentavos),
        qty: current?.qty ?? 0,
        onQty: (qty) => onChanged(
          CamporeeOrderDraftLine(
            camporeeMemberId: member.camporeeMemberId,
            memberName: memberName,
            offeringId: offering.offeringId,
            productTitle: offering.product.title,
            qty: qty,
            unitPriceCentavos: offering.priceCentavos,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offering.product.title,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              Text(
                SacMoney.fromCentavos(offering.priceCentavos),
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  fontWeight: FontWeight.w700,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final option in options)
            _QtyRow(
              title: option.label,
              qty: lines
                  .where(
                    (line) =>
                        line.offeringId == offering.offeringId &&
                        line.optionId == option.optionId,
                  )
                  .fold<int>(0, (sum, line) => sum + line.qty),
              onQty: (qty) => onChanged(
                CamporeeOrderDraftLine(
                  camporeeMemberId: member.camporeeMemberId,
                  memberName: memberName,
                  offeringId: offering.offeringId,
                  productTitle: offering.product.title,
                  optionId: option.optionId,
                  optionLabel: option.label,
                  qty: qty,
                  unitPriceCentavos: offering.priceCentavos,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QtyRow extends StatelessWidget {
  final String title;
  final String? priceLabel;
  final int qty;
  final ValueChanged<int> onQty;

  const _QtyRow({
    required this.title,
    required this.qty,
    required this.onQty,
    this.priceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              priceLabel == null ? title : '$title · $priceLabel',
              style: TextStyle(fontSize: SacFontSize.bodyMedium, color: c.text),
            ),
          ),
          SacPressable(
            listenOnly: true,
            child: IconButton(
              enableFeedback: false,
              tooltip: 'common.decrease_quantity'.tr(),
              onPressed: qty <= 0 ? null : () => onQty(qty - 1),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedMinusSign,
                size: 16,
                color: c.textSecondary,
              ),
            ),
          ),
          Text(
            '$qty',
            style: TextStyle(
              fontSize: SacFontSize.titleSmall,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          SacPressable(
            listenOnly: true,
            child: IconButton(
              enableFeedback: false,
              tooltip: 'common.increase_quantity'.tr(),
              onPressed: () => onQty(qty + 1),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                size: 16,
                color: SacAccent.of(context).color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureFooter extends StatelessWidget {
  final int lineCount;
  final int totalCentavos;
  final VoidCallback? onContinue;

  const _CaptureFooter({
    required this.lineCount,
    required this.totalCentavos,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lineCount == 0
                ? 'camporee_orders.capture.no_lines'.tr()
                : '${'camporee_orders.capture.lines_count'.tr(namedArgs: {
                        'count': lineCount.toString(),
                      })} · ${SacMoney.fromCentavos(totalCentavos)}',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: SacFontSize.bodyMedium, color: c.textSecondary),
          ),
          const SizedBox(height: 10),
          SacButton.primary(
            text: 'camporee_orders.capture.continue'.tr(),
            isEnabled: onContinue != null,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}
