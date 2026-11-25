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
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_union_camporee.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_union_camporees_providers.dart';
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final camporee in camporees)
              _CamporeeBlock(
                camporee: camporee,
                canApprove: canApprove,
                canConfigure: canConfigure,
              ),
          ],
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

class _CamporeeBlock extends StatelessWidget {
  const _CamporeeBlock({
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
    final where = [
      camporeeDateRange(context, camporee.startDate, camporee.endDate),
      camporee.place,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final id = '${camporee.id}';

    final rows = <Widget>[
      if (canApprove)
        _ApprovalsRow(
          camporeeId: camporee.id,
          onTap: () => context.push(
            RouteNames.supervisionUnionCamporeeApprovals(id),
          ),
        ),
      if (canConfigure)
        SacListRow(
          leading: const SacListRowIcon(HugeIcons.strokeRoundedShoppingBag01),
          title: 'supervision.union_camporees.orders_row'.tr(),
          subtitle: _ordersStatus(context, camporee),
          onTap: () => context.push(
            RouteNames.supervisionUnionCamporeeOrders(id),
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camporee.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.headlineSmall,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.25,
                      color: c.text,
                    ),
                  ),
                  if (where.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      where,
                      maxLines: 3,
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
          if (rows.isNotEmpty)
            Material(
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
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 58,
                        color: c.divider,
                      ),
                    rows[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Where the order window stands right now, in a few words.
String _ordersStatus(BuildContext context, SupervisionUnionCamporee camporee) {
  if (!camporee.ordersEnabled) {
    return 'supervision.union_camporees.orders_disabled'.tr();
  }
  final now = DateTime.now();
  final opens = camporee.ordersOpensAt;
  final deadline = camporee.ordersDeadline;
  if (deadline != null && now.isAfter(deadline)) {
    return 'supervision.union_camporees.orders_closed'.tr();
  }
  if (opens != null && now.isBefore(opens)) {
    return 'supervision.union_camporees.orders_opens_on'
        .tr(args: [supervisionShortDate(context, opens.toLocal())]);
  }
  return 'supervision.union_camporees.orders_open'.tr();
}

/// Entry to the approvals of one camporee, with its live pending count.
class _ApprovalsRow extends ConsumerWidget {
  const _ApprovalsRow({required this.camporeeId, required this.onTap});

  final int camporeeId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final pending = ref.watch(supervisionCamporeePendingProvider(camporeeId));
    final total = pending.value?.total;

    final String subtitle;
    if (total == null) {
      // Loading or failed: say what the row holds instead of a wrong count.
      subtitle = 'supervision.union_camporees.approvals_description'.tr();
    } else if (total > 0) {
      subtitle = 'supervision.union_camporees.pending_count'
          .tr(args: [supervisionCount(context, total)]);
    } else {
      subtitle = 'supervision.union_camporees.up_to_date'.tr();
    }

    return SacListRow(
      leading: const SacListRowIcon(HugeIcons.strokeRoundedUserAdd01),
      title: 'supervision.union_camporees.approvals_row'.tr(),
      subtitle: subtitle,
      subtitleColor: total != null && total > 0 ? c.text : null,
      onTap: onTap,
    );
  }
}
