import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_union_camporee.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_union_camporees_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_count_pill.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_scroll.dart';

/// Active camporees of the union, each with what the actor can do in it:
/// decide the late registrations and payments, and set up orders and supplies.
class SupervisionUnionCamporeesView extends ConsumerWidget {
  const SupervisionUnionCamporeesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final async = ref.watch(supervisionUnionCamporeesProvider);
    // A failed refresh keeps the last list on screen.
    final camporees = async.value;

    Future<void> refresh() async {
      ref.invalidate(supervisionUnionCamporeesProvider);
      ref.invalidate(supervisionCamporeePendingProvider);
      try {
        await ref.read(supervisionUnionCamporeesProvider.future);
      } catch (_) {
        // The body renders the error.
      }
    }

    final Widget body;
    if (camporees == null && async.hasError) {
      body = SupervisionScroll(
        onRefresh: refresh,
        fill: true,
        child: isForbiddenFailure(async.error!)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'supervision.union_camporees.error_title'.tr(),
                message: 'supervision.union_camporees.error_message'.tr(),
                onRetry: refresh,
              ),
      );
    } else if (camporees == null) {
      body = SupervisionScroll(
        onRefresh: refresh,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: SacSkeletonList(
            itemCount: 4,
            leading: false,
            scrollable: false,
          ),
        ),
      );
    } else if (camporees.isEmpty) {
      body = SupervisionScroll(
        onRefresh: refresh,
        fill: true,
        child: SacEmptyState(
          icon: HugeIcons.strokeRoundedCampfire,
          title: 'supervision.union_camporees.empty_title'.tr(),
          body: 'supervision.union_camporees.empty_body'.tr(),
        ),
      );
    } else {
      final user = ref.watch(authNotifierProvider.select((v) => v.value));
      final canApprove =
          hasCapability(user, 'union_camporees.approve_registrations');
      final canConfigure =
          hasCapability(user, 'camporee_orders.configure_offering');
      body = SupervisionScroll(
        onRefresh: refresh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ActiveEyebrow(count: camporees.length),
              for (var i = 0; i < camporees.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _CamporeeCard(
                  key: ValueKey(camporees[i].id),
                  camporee: camporees[i],
                  canApprove: canApprove,
                  canConfigure: canConfigure,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'supervision.union_camporees.title'.tr(),
        frosted: true,
      ),
      body: SacFrostedVeil(child: body),
    );
  }
}

/// "12 nov 2026 – 15 nov 2026", or the single day it has.
String camporeeDateRange(BuildContext context, DateTime? start, DateTime? end) {
  if (start == null && end == null) return '';
  if (start == null || end == null || start == end) {
    return supervisionShortDate(context, (start ?? end)!);
  }
  return '${supervisionShortDate(context, start)} – '
      '${supervisionShortDate(context, end)}';
}

/// «ACTIVOS · 2»: eyebrow over the camporee cards.
class _ActiveEyebrow extends StatelessWidget {
  const _ActiveEyebrow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: SacFontSize.labelSmall,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: context.sac.textTertiary,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'supervision.union_camporees.active_label'.tr().toUpperCase(),
                style: style,
              ),
            ),
          ),
          Text('$count', style: style),
        ],
      ),
    );
  }
}

/// One camporee as one grouped card: its header (campfire tile, name, dates and
/// place) and, under it, the functions the actor may use.
class _CamporeeCard extends StatelessWidget {
  const _CamporeeCard({
    super.key,
    required this.camporee,
    required this.canApprove,
    required this.canConfigure,
  });

  final SupervisionUnionCamporee camporee;
  final bool canApprove;
  final bool canConfigure;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final id = '${camporee.id}';
    final rows = <Widget>[
      _CamporeeHeader(camporee: camporee),
      if (canApprove)
        _ApprovalsRow(
          camporeeId: camporee.id,
          onTap: () => context.push(
            RouteNames.supervisionUnionCamporeeApprovals(id),
          ),
        ),
      if (canConfigure)
        _OrdersRow(
          camporee: camporee,
          onTap: () => context.push(
            RouteNames.supervisionUnionCamporeeOrders(id),
          ),
        ),
    ];

    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        side: BorderSide(color: c.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, indent: 14, color: c.divider),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _CamporeeHeader extends StatelessWidget {
  const _CamporeeHeader({required this.camporee});

  final SupervisionUnionCamporee camporee;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final palette = SacTonePalette.of(context, SacTone.warning);
    final where = [
      camporeeDateRange(context, camporee.startDate, camporee.endDate),
      camporee.place,
    ].where((part) => part.trim().isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.container,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: ExcludeSemantics(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCampfire,
                size: 24,
                color: palette.onContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camporee.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: c.text,
                    ),
                  ),
                  if (where.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      where,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        height: 1.3,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The order window of one camporee seen from now.
enum _OrdersState { disabled, closed, opensLater, open }

_OrdersState _ordersStateOf(SupervisionUnionCamporee camporee) {
  if (!camporee.ordersEnabled) return _OrdersState.disabled;
  final now = DateTime.now();
  final opens = camporee.ordersOpensAt;
  final deadline = camporee.ordersDeadline;
  if (deadline != null && now.isAfter(deadline)) return _OrdersState.closed;
  if (opens != null && now.isBefore(opens)) return _OrdersState.opensLater;
  return _OrdersState.open;
}

/// Entry to orders and supplies, with the state of the window as subtitle.
class _OrdersRow extends StatelessWidget {
  const _OrdersRow({required this.camporee, required this.onTap});

  final SupervisionUnionCamporee camporee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final state = _ordersStateOf(camporee);
    final success = SacTonePalette.of(context, SacTone.success).onContainer;
    final deadline = camporee.ordersDeadline;

    List<TextSpan>? spans;
    String? text;
    switch (state) {
      case _OrdersState.disabled:
        text = 'supervision.union_camporees.orders_disabled'.tr();
      case _OrdersState.closed:
        text = 'supervision.union_camporees.orders_closed'.tr();
      case _OrdersState.opensLater:
        text = 'supervision.union_camporees.orders_opens_on'.tr(args: [
          supervisionShortDate(context, camporee.ordersOpensAt!.toLocal()),
        ]);
      case _OrdersState.open:
        spans = [
          TextSpan(
            text: 'supervision.union_camporees.orders_open'.tr(),
            style: TextStyle(color: success, fontWeight: FontWeight.w600),
          ),
          if (deadline != null)
            TextSpan(
              text: ' · ${'supervision.union_camporees.orders_closes_on'.tr(
                args: [supervisionShortDate(context, deadline.toLocal())],
              )}',
              style: TextStyle(color: c.textSecondary),
            ),
        ];
    }

    return SacListRow(
      leading: SacListRowIcon(
        HugeIcons.strokeRoundedShoppingBag01,
        tone: state == _OrdersState.open ? SacTone.success : SacTone.muted,
      ),
      title: 'supervision.union_camporees.orders_row'.tr(),
      subtitle: text,
      subtitleSpans: spans,
      onTap: onTap,
    );
  }
}

/// Entry to the approvals of one camporee, with its live pending count.
class _ApprovalsRow extends ConsumerWidget {
  const _ApprovalsRow({required this.camporeeId, required this.onTap});

  final int camporeeId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(supervisionCamporeePendingProvider(camporeeId));
    final total = pending.value?.total;
    final hasPending = total != null && total > 0;

    // Loading or failed: say what the row holds instead of a wrong count.
    final Widget? subtitleWidget = total != null && total == 0
        ? SupervisionAllClearLabel(
            label: 'supervision.union_camporees.up_to_date'.tr(),
          )
        : null;
    final subtitle = hasPending
        ? 'supervision.union_camporees.late_label'.tr()
        : 'supervision.union_camporees.approvals_description'.tr();

    return SacListRow(
      leading: SacListRowIcon(
        HugeIcons.strokeRoundedUserAdd01,
        tone: hasPending
            ? SacTone.warning
            : (total == null ? SacTone.accent : SacTone.success),
      ),
      title: 'supervision.union_camporees.approvals_row'.tr(),
      subtitle: subtitle,
      subtitleWidget: subtitleWidget,
      trailing: hasPending
          ? SupervisionCountPill(
              count: total,
              semanticLabel: 'supervision.union_camporees.pending_count'
                  .tr(args: [supervisionCount(context, total)]),
            )
          : null,
      onTap: onTap,
    );
  }
}
