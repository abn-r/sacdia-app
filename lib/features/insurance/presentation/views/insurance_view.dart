import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/back_or_home.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/insurance_overview.dart';
import '../providers/insurance_providers.dart';
import '../utils/insurance_formatting.dart';
import '../widgets/insurance_message_state.dart';
import '../widgets/insurance_skeleton.dart';
import '../widgets/insurance_summary_box.dart';
import '../widgets/insurance_ui.dart';

/// Seguros del club: quién está cubierto este año, quién está en trámite y
/// quién falta. Cuenta a miembros y directiva.
class InsuranceView extends ConsumerStatefulWidget {
  const InsuranceView({super.key});

  @override
  ConsumerState<InsuranceView> createState() => _InsuranceViewState();
}

class _InsuranceViewState extends ConsumerState<InsuranceView> {
  InsuranceFilter _filter = InsuranceFilter.all;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(insuranceOverviewProvider)
      ..invalidate(freeCoveragesProvider);
    try {
      await ref.read(insuranceOverviewProvider.future);
    } catch (_) {
      // The error is painted from the provider state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final overviewAsync = ref.watch(insuranceOverviewProvider);
    final access =
        ref.watch(insuranceAccessProvider).value ?? InsuranceAccess.readOnly;
    final overview = overviewAsync.value;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        // Same as the other module screens (Clase agrupada, Unidades): the
        // title lives in the bar, next to the back arrow.
        title: tr('insurance.home.title'),
        backgroundColor: c.canvas,
        frosted: true,
        onBack: () => backOrHome(context),
        actions: [
          if (access.canViewOrders)
            SacPressable(
              listenOnly: true,
              child: IconButton(
                enableFeedback: false,
                tooltip: tr('insurance.home.orders_tooltip'),
                onPressed: () => context.push(
                  '${RouteNames.paymentOrders}?purpose=INSURANCE',
                ),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedInvoice01,
                  color: c.text,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
      body: SacFrostedVeil(
        child: overview == null && overviewAsync.isLoading
            ? const InsuranceSkeleton()
            : overview == null && overviewAsync.hasError
                ? InsuranceMessageState.loadError(
                    error: overviewAsync.error,
                    onRetry: _refresh,
                  )
                : overview == null
                    ? InsuranceMessageState(
                        title: tr('insurance.states.no_section_title'),
                        body: tr('insurance.states.no_section_body'),
                        icon: HugeIcons.strokeRoundedShield01,
                      )
                    : _Body(
                        overview: overview,
                        access: access,
                        filter: _filter,
                        query: _query,
                        searchController: _search,
                        onFilter: (f) => setState(() => _filter = f),
                        onQuery: (q) => setState(() => _query = q),
                        onRefresh: _refresh,
                      ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.overview,
    required this.access,
    required this.filter,
    required this.query,
    required this.searchController,
    required this.onFilter,
    required this.onQuery,
    required this.onRefresh,
  });

  final InsuranceOverview overview;
  final InsuranceAccess access;
  final InsuranceFilter filter;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<InsuranceFilter> onFilter;
  final ValueChanged<String> onQuery;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final year = overview.year?.label ?? '';
    final noCost = overview.cycle == null;
    final canIssue =
        access.canIssue && !noCost && overview.counts.uninsured > 0;

    final List<Widget> content;
    if (overview.year == null) {
      content = [
        _Message(
          icon: HugeIcons.strokeRoundedCalendar03,
          title: tr('insurance.states.no_year_title'),
          body: tr('insurance.states.no_year_body'),
        ),
      ];
    } else if (noCost) {
      content = [
        _Message(
          icon: HugeIcons.strokeRoundedCalendar03,
          title:
              tr('insurance.states.no_cost_title', namedArgs: {'year': year}),
          body: tr('insurance.states.no_cost_body'),
        ),
      ];
    } else if (overview.counts.total == 0) {
      content = [
        _Message(
          icon: HugeIcons.strokeRoundedUserGroup,
          title: tr('insurance.states.no_people_title'),
          body: tr('insurance.states.no_people_body'),
        ),
      ];
    } else {
      content = [
        InsuranceSummaryBox(overview: overview),
        if (overview.isAllCovered)
          _Message(
            key: const ValueKey('insurance-all-covered'),
            icon: HugeIcons.strokeRoundedShieldUser,
            title: tr('insurance.states.all_covered_title'),
            body: tr(
              'insurance.states.all_covered_body',
              namedArgs: {'next': _nextYear(overview.year!)},
            ),
          )
        else if (overview.isYearStart())
          _Message(
            key: const ValueKey('insurance-year-start'),
            icon: HugeIcons.strokeRoundedCalendar03,
            title: tr('insurance.states.year_start_title',
                namedArgs: {'year': year}),
            body: overview.cycle?.purchaseDeadline == null
                ? tr('insurance.states.year_start_body_no_date')
                : tr(
                    'insurance.states.year_start_body',
                    namedArgs: {
                      'date': insuranceShortDate(
                        context,
                        overview.cycle!.purchaseDeadline!,
                      ),
                    },
                  ),
          ),
        _ToAttend(overview: overview, access: access),
        _PeopleList(
          overview: overview,
          access: access,
          filter: filter,
          query: query,
          controller: searchController,
          onFilter: onFilter,
          onQuery: onQuery,
        ),
        if (!access.canIssue && !access.canReassign)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              tr('insurance.home.read_only_note'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                height: 1.4,
                color: c.textSecondary,
              ),
            ),
          ),
      ];
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: SacAccent.of(context).color,
          edgeOffset: SacTopBar.frostedInset(context),
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: SacTopBar.paddingBelowBar(
              context,
              EdgeInsets.only(
                top: 4,
                bottom: 32 + (canIssue ? InsuranceFooter.height : 0),
              ),
            ),
            children: content,
          ),
        ),
        if (canIssue)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: InsuranceFooter(
              button: SacButton.primary(
                key: const ValueKey('insurance-issue-cta'),
                text: overview.isYearStart()
                    ? tr(
                        'insurance.home.issue_cta_all',
                        namedArgs: {'count': '${overview.counts.uninsured}'},
                      )
                    : tr(
                        'insurance.home.issue_cta',
                        namedArgs: {'count': '${overview.counts.uninsured}'},
                      ),
                icon: HugeIcons.strokeRoundedShield01,
                onPressed: () => context.push(RouteNames.homeInsuranceIssue),
              ),
            ),
          ),
      ],
    );
  }

  String _nextYear(InsuranceYear year) {
    final n = int.tryParse(year.label);
    return n == null ? year.label : '${n + 1}';
  }
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final HugeIconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: SacEmptyState.inline(title: title, body: body, icon: icon),
    );
  }
}

/// Free insurances and orders that wait for the director.
class _ToAttend extends ConsumerWidget {
  const _ToAttend({required this.overview, required this.access});

  final InsuranceOverview overview;
  final InsuranceAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final free = access.canReassign
        ? (ref.watch(freeCoveragesProvider).value ?? const <FreeCoverage>[])
        : const <FreeCoverage>[];
    final rejected = access.canViewOrders
        ? overview.rejectedOrders
        : const <InsuranceOrderSummary>[];
    final needing = access.canViewOrders
        ? overview.ordersNeedingReceipt
        : const <InsuranceOrderSummary>[];
    final rows = <Widget>[
      for (final f in free)
        SacStatusRow(
          key: ValueKey('insurance-free-${f.assignmentId}'),
          style: SacStatusStyle.of(
            context,
            SacStatusKind.review,
            label: tr('insurance.attend.free_label'),
            icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
          ),
          title: tr('insurance.attend.free_title',
              namedArgs: {'name': f.holderName}),
          detail: tr('insurance.attend.free_detail'),
          onTap: () => context.push(
            RouteNames.homeInsuranceReassignPath(assignmentId: f.assignmentId),
          ),
        ),
      for (final o in rejected)
        SacStatusRow(
          key: ValueKey('insurance-rejected-${o.order.orderId}'),
          style: SacStatusStyle.of(
            context,
            SacStatusKind.rejected,
            label: tr('insurance.attend.rejected_label'),
          ),
          title: tr('insurance.attend.rejected_title'),
          detail: _orderLine(context, o),
          onTap: () => context.push(
            RouteNames.paymentOrderDetailPath(o.order.orderId),
          ),
        ),
      for (final o in needing)
        SacStatusRow(
          key: ValueKey('insurance-needs-receipt-${o.order.orderId}'),
          style: SacStatusStyle.of(
            context,
            SacStatusKind.review,
            label: tr('insurance.attend.receipt_label'),
            icon: HugeIcons.strokeRoundedUpload01,
          ),
          title: tr('insurance.attend.receipt_title'),
          detail: _receiptLine(context, o),
          onTap: () => context.push(
            RouteNames.paymentOrderDetailPath(o.order.orderId),
          ),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return SacGroupedSection(
      key: const ValueKey('insurance-to-attend'),
      label: tr('insurance.attend.title'),
      children: rows,
    );
  }

  String _orderLine(BuildContext context, InsuranceOrderSummary o) =>
      '${o.order.folio} · '
      '${'insurance.attend.people_count'.plural(o.peopleCount)}';

  String _receiptLine(BuildContext context, InsuranceOrderSummary o) {
    final expires = o.order.expiresAt;
    return expires == null
        ? o.order.folio
        : tr(
            'insurance.attend.receipt_detail',
            namedArgs: {
              'folio': o.order.folio,
              'date': insuranceShortDate(context, expires),
            },
          );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({
    required this.overview,
    required this.access,
    required this.filter,
    required this.query,
    required this.controller,
    required this.onFilter,
    required this.onQuery,
  });

  final InsuranceOverview overview;
  final InsuranceAccess access;
  final InsuranceFilter filter;
  final String query;
  final TextEditingController controller;
  final ValueChanged<InsuranceFilter> onFilter;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final q = insuranceNormalize(query.trim());
    final shown = overview.people
        .where((p) => insuranceFilterMatches(filter, p))
        .where((p) => q.isEmpty || insuranceNormalize(p.name).contains(q))
        .toList(growable: false);
    final counts = overview.counts;
    final chips = <(InsuranceFilter, String, int)>[
      (InsuranceFilter.all, tr('insurance.filter.all'), counts.total),
      (
        InsuranceFilter.uninsured,
        tr('insurance.filter.uninsured'),
        counts.uninsured,
      ),
      (
        InsuranceFilter.inProcess,
        tr('insurance.filter.in_process'),
        counts.inProcess,
      ),
      (InsuranceFilter.covered, tr('insurance.filter.covered'), counts.covered),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            children: [
              for (final chip in chips) ...[
                _FilterChip(
                  label: chip.$2,
                  count: chip.$3,
                  selected: filter == chip.$1,
                  onTap: () => onFilter(chip.$1),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  size: 18,
                  color: c.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onQuery,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      color: c.text,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: tr('insurance.home.search_hint'),
                      hintStyle: TextStyle(color: c.textTertiary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: SacEmptyState.inline(
              title: tr('insurance.home.no_results'),
              icon: HugeIcons.strokeRoundedSearch01,
            ),
          )
        else
          SacGroupedSection(
            key: const ValueKey('insurance-people'),
            label: tr('insurance.home.people_title'),
            children: [
              for (final person in shown)
                _PersonRow(person: person, access: access),
            ],
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      excludeSemantics: true,
      onTap: onTap,
      child: Align(
        child: SacInkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? c.ink900 : c.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(color: selected ? c.ink900 : c.border),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label),
                    TextSpan(
                      text: '  $count',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: (selected ? c.paper : c.textSecondary)
                            .withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w600,
                  color: selected ? c.paper : c.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.access});

  final InsurancePerson person;
  final InsuranceAccess access;

  VoidCallback? _onTap(BuildContext context) {
    switch (person.status) {
      case InsurancePersonStatus.covered:
        return () => context.push(
              RouteNames.homeInsurancePersonPath(person.userId),
            );
      case InsurancePersonStatus.uninsured:
        return access.canIssue
            ? () => context.push(RouteNames.homeInsuranceIssue)
            : null;
      case InsurancePersonStatus.inOrder:
      case InsurancePersonStatus.inReview:
      case InsurancePersonStatus.proofRejected:
        final id = person.activeOrder?.orderId;
        if (id == null || id.isEmpty || !access.canViewOrders) return null;
        return () => context.push(RouteNames.paymentOrderDetailPath(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = _onTap(context);
    final detail = insuranceDetail(context, person);
    return InsuranceRow(
      key: ValueKey('insurance-person-${person.userId}'),
      leading: InsuranceAvatar(name: person.name, imageUrl: person.picture),
      title: person.name,
      detail: detail,
      detailIsError: person.status == InsurancePersonStatus.proofRejected,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: InsuranceStatusChip(status: person.status)),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const InsuranceChevron(),
          ],
        ],
      ),
      onTap: onTap,
      semanticLabel: '${person.name}, ${insuranceStatusLabel(person.status)}, '
          '$detail',
    );
  }
}
