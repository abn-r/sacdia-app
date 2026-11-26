import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/supervision_route_access.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/clubless_home_header.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_count_pill.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_summary_box.dart';

/// Widest the hub lists grow on a tablet.
const double _kMaxContentWidth = 640;

const String _kUnconfiguredLevel = kUnconfiguredTerritoryLevel;

/// Root of the territorial supervision surface (Union / Division).
///
/// Without a club it is the home: the club dashboard's greeting header
/// (`ClubLessHomeHeader`) on top, then a «Por atender» summary and two grouped
/// lists: the queues that wait for a decision, each with its live pending
/// count, and the read-only views of the territory. With a club it is a tab
/// and keeps its top bar. A row exists only when the server granted its
/// capability. The counts load on their own: a failure never blocks the way
/// into a function.
class SupervisionHubView extends ConsumerStatefulWidget {
  const SupervisionHubView({super.key});

  @override
  ConsumerState<SupervisionHubView> createState() => _SupervisionHubViewState();
}

class _SupervisionHubViewState extends ConsumerState<SupervisionHubView>
    with WidgetsBindingObserver {
  bool _rechecking = false;
  bool _recheckedWithoutChange = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The queues move while the app is away: never show yesterday's count.
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(supervisionPendingCountsProvider);
    }
  }

  Future<void> _refreshCounts() async {
    ref.invalidate(supervisionPendingCountsProvider);
    try {
      await ref.read(supervisionPendingCountsProvider.future);
    } catch (_) {
      // The queue section renders its own error.
    }
  }

  Future<void> _recheckTerritory() async {
    if (_rechecking) return;
    setState(() => _rechecking = true);
    await ref
        .read(authNotifierProvider.notifier)
        .refreshAuthorization(minInterval: Duration.zero);
    if (!mounted) return;
    setState(() {
      _rechecking = false;
      _recheckedWithoutChange = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final level = user?.authorization?.territory?.level;
    final unconfigured = level == _kUnconfiguredLevel;
    // Without a club this is the home and there is no other bell or greeting;
    // with a club it is a tab and keeps its plain top bar.
    final isHome = isSupervisorWithoutClub(user);

    final queues = unconfigured ? const <_Queue>[] : _queuesFor(user);
    final views = unconfigured ? const <_TerritoryView>[] : _viewsFor(user);

    final header = isHome
        ? ClubLessHomeHeader(
            sectionTitle: 'router.nav.supervision'.tr(),
            // The server's territory name when it sends one; older servers
            // only send ids, and the level is what the app can say then.
            contextLabel: _territoryName(user) ?? _levelLabel(level),
          )
        : null;

    final Widget body;
    if (unconfigured) {
      body = _HubScroll(
        header: header,
        onRefresh: _recheckTerritory,
        footer: SacFrostedFooter(
          child: SacButton(
            text: 'supervision.hub.unconfigured_action'.tr(),
            icon: HugeIcons.strokeRoundedRefresh,
            fullWidth: true,
            labelMaxLines: 2,
            isLoading: _rechecking,
            onPressed: _recheckTerritory,
          ),
        ),
        child: _UnconfiguredTerritory(
          checkedWithoutChange: _recheckedWithoutChange && !_rechecking,
        ),
      );
    } else if (queues.isEmpty && views.isEmpty) {
      body = _HubScroll(
        header: header,
        onRefresh: () => ref
            .read(authNotifierProvider.notifier)
            .refreshAuthorization(minInterval: Duration.zero),
        fill: true,
        child: SacEmptyState(
          icon: HugeIcons.strokeRoundedAnalytics01,
          title: 'supervision.hub.no_functions_title'.tr(),
          body: 'supervision.hub.no_functions_body'.tr(),
        ),
      );
    } else {
      body = _HubScroll(
        header: header,
        onRefresh: queues.isEmpty ? () async {} : _refreshCounts,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (queues.isNotEmpty)
              _QueuesSection(queues: queues, onRetry: _refreshCounts),
            if (views.isNotEmpty) _TerritorySection(views: views),
          ],
        ),
      );
    }

    if (isHome) {
      return Scaffold(
        backgroundColor: c.background,
        body: SafeArea(bottom: false, child: body),
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'router.nav.supervision'.tr(),
        subtitle: _levelLabel(level),
        frosted: true,
        automaticallyImplyLeading: false,
      ),
      body: SacFrostedVeil(child: body),
    );
  }
}

String? _territoryName(UserEntity? user) {
  final name = user?.authorization?.territory?.name?.trim();
  return name == null || name.isEmpty ? null : name;
}

String? _levelLabel(String? level) => switch (level) {
      'union' => 'supervision.hub.level_union'.tr(),
      'division' => 'supervision.hub.level_division'.tr(),
      _ => null,
    };

// ── What the actor may open ─────────────────────────────────────────────────

/// A queue that waits for a decision; its row carries a live pending count.
enum _Queue {
  enrollments(
    icon: HugeIcons.strokeRoundedUserAdd01,
    route: RouteNames.supervisionEnrollments,
    key: 'enrollments',
    tone: SacTone.accent,
  ),
  folders(
    icon: HugeIcons.strokeRoundedFolder01,
    route: RouteNames.supervisionFolders,
    key: 'folders',
    tone: SacTone.info,
  ),
  requests(
    icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
    route: RouteNames.supervisionRequests,
    key: 'requests',
    tone: SacTone.success,
  ),
  unionCamporees(
    icon: HugeIcons.strokeRoundedCampfire,
    route: RouteNames.supervisionUnionCamporees,
    key: 'union_camporees',
    tone: SacTone.warning,
  );

  const _Queue({
    required this.icon,
    required this.route,
    required this.key,
    required this.tone,
  });

  final HugeIconData icon;
  final String route;
  final String key;

  /// Color of its slice in the «Por atender» bar. Distinct per queue; the
  /// legend names each one, so color is never the only signal.
  final SacTone tone;

  String get title => 'supervision.hub.$key.title'.tr();
  String get description => 'supervision.hub.$key.description'.tr();
  String get shortTitle => 'supervision.hub.$key.short'.tr();
  String pending(int count) =>
      'supervision.hub.$key.pending'.tr(args: ['$count']);

  int? countIn(SupervisionPendingCounts counts) => switch (this) {
        _Queue.enrollments => counts.clubEnrollments,
        _Queue.folders => counts.annualFolders,
        _Queue.requests => counts.requests,
        _Queue.unionCamporees => counts.unionCamporeeRegistrations,
      };
}

/// A read-only view of the territory.
enum _TerritoryView {
  operations(
    icon: HugeIcons.strokeRoundedChartBarLine,
    route: RouteNames.supervisionOperations,
    key: 'operations',
    capability: 'analytics.operations_dashboard',
  ),
  clubs(
    icon: HugeIcons.strokeRoundedBuilding01,
    route: RouteNames.supervisionClubs,
    key: 'clubs',
    capability: 'clubs.view_territory',
  ),
  reports(
    icon: HugeIcons.strokeRoundedFile01,
    route: RouteNames.supervisionReports,
    key: 'reports',
    capability: 'reports.view_territory',
  ),
  annualProgress(
    icon: HugeIcons.strokeRoundedChartLineData01,
    route: RouteNames.supervisionAnnualProgress,
    key: 'annual_progress',
    capability: 'annual_progress.view_territory',
  );

  const _TerritoryView({
    required this.icon,
    required this.route,
    required this.key,
    required this.capability,
  });

  final HugeIconData icon;
  final String route;
  final String key;
  final String capability;

  String get title => 'supervision.hub.$key.title'.tr();
  String get description => 'supervision.hub.$key.description'.tr();
}

List<_Queue> _queuesFor(UserEntity? user) => [
      if (hasCapability(user, 'club_enrollments.validate')) _Queue.enrollments,
      if (hasCapability(user, 'folders.evaluate')) _Queue.folders,
      if (hasCapability(user, 'requests.review_territory')) _Queue.requests,
      // Approvals and orders share one entry. It follows the gate of the
      // camporee list it opens, so the row never leads to «Acceso
      // restringido»; inside, each camporee offers what the actor can do.
      if (hasCapability(user, 'union_camporees.approve_registrations'))
        _Queue.unionCamporees,
    ];

List<_TerritoryView> _viewsFor(UserEntity? user) => [
      for (final view in _TerritoryView.values)
        if (hasCapability(user, view.capability)) view,
    ];

// ── Scroll scaffold ─────────────────────────────────────────────────────────

class _HubScroll extends StatelessWidget {
  const _HubScroll({
    required this.onRefresh,
    required this.child,
    this.header,
    this.footer,
    this.fill = false,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// The club-less greeting. Null: the top bar of the Scaffold is above.
  final Widget? header;

  /// Fixed bottom action (a [SacFrostedFooter]); the list leaves room for it.
  final Widget? footer;

  /// Centers [child] in the viewport (empty state).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    Widget bounded(Widget content) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
            child: content,
          ),
        );
    // Under a top bar the content starts below it; with the greeting header it
    // is the first thing in the scroll.
    final topInset = header == null ? SacTopBar.frostedInset(context) : 0.0;
    final bottom = footer == null ? 32.0 : SacFrostedFooter.height;

    final scroll = RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: topInset,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (header != null) SliverToBoxAdapter(child: bounded(header!)),
          if (fill)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(top: header == null ? topInset : 0),
                child: bounded(child),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(
                top: header == null ? topInset + 4 : 0,
                bottom: bottom,
              ),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: bounded(child),
                ),
              ),
            ),
        ],
      ),
    );
    if (footer == null) return scroll;
    return Stack(
      children: [
        Positioned.fill(child: scroll),
        Positioned(left: 0, right: 0, bottom: 0, child: footer!),
      ],
    );
  }
}

// ── "Por atender" ───────────────────────────────────────────────────────────

class _QueuesSection extends ConsumerWidget {
  const _QueuesSection({required this.queues, required this.onRetry});

  final List<_Queue> queues;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(supervisionPendingCountsProvider);
    // A refresh keeps the last counts on screen instead of flashing bones.
    final counts = countsAsync.value;
    final loading = countsAsync.isLoading && counts == null;
    final failed = countsAsync.hasError &&
        !countsAsync.isLoading &&
        !isForbiddenFailure(countsAsync.error!);

    int? countOf(_Queue queue) => counts == null ? null : queue.countIn(counts);
    final withPending = [
      for (final queue in queues)
        if ((countOf(queue) ?? 0) > 0) queue,
    ];
    final total = withPending.fold<int>(0, (sum, q) => sum + countOf(q)!);
    // Every queue answered 0 (a `null` is «no data», not «nothing»).
    final allClear =
        counts != null && queues.every((queue) => countOf(queue) == 0);

    final Widget top;
    if (loading) {
      top = const _SummarySkeleton();
    } else if (total > 0) {
      top = _PendingSummary(
        total: total,
        queuesWithPending: withPending,
        queuesTotal: queues.length,
        countOf: (queue) => countOf(queue)!,
      );
    } else if (allClear) {
      top = const _AllClearPanel();
    } else {
      top = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        SacGroupedSection(
          label: 'supervision.hub.queues_title'.tr(),
          // «3 de 4»: queues with something waiting out of the ones held. No
          // figure until the counts arrive.
          action: counts == null
              ? const SizedBox.shrink()
              : _QueuesCount(
                  label: 'supervision.hub.queues_count'
                      .tr(args: ['${withPending.length}', '${queues.length}'])),
          children: [
            for (final queue in queues)
              _queueRow(context, queue, loading, countOf(queue)),
          ],
        ),
        if (failed && counts == null) _CountsError(onRetry: onRetry),
      ],
    );
  }

  Widget _queueRow(
    BuildContext context,
    _Queue queue,
    bool loading,
    int? count,
  ) {
    return SacListRow(
      // Muted once the queue is known to be empty: the tint says «look here».
      leading: SacListRowIcon(
        queue.icon,
        tone: count == 0 ? SacTone.muted : SacTone.accent,
      ),
      title: queue.title,
      onTap: () => context.push(queue.route),
      subtitleWidget: _QueueStatus(
        loading: loading,
        count: count,
        pendingLabel: queue.pending,
        description: queue.description,
      ),
      // The second line already says the number: keep the row one phrase.
      trailing: count != null && count > 0
          ? ExcludeSemantics(child: SupervisionCountPill(count: count))
          : null,
    );
  }
}

/// «3 DE 4» at the end of the «Por atender» eyebrow.
class _QueuesCount extends StatelessWidget {
  const _QueuesCount({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w600,
          color: context.sac.textTertiary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
}

/// «Por atender» box: total waiting, how many queues hold it, and the
/// composition by queue.
class _PendingSummary extends StatelessWidget {
  const _PendingSummary({
    required this.total,
    required this.queuesWithPending,
    required this.queuesTotal,
    required this.countOf,
  });

  final int total;
  final List<_Queue> queuesWithPending;
  final int queuesTotal;
  final int Function(_Queue queue) countOf;

  @override
  Widget build(BuildContext context) {
    final inQueues = (queuesTotal == 1
            ? 'supervision.hub.summary_in_queues_one'
            : 'supervision.hub.summary_in_queues')
        .tr(args: ['${queuesWithPending.length}', '$queuesTotal']);
    return SupervisionSummaryBox(
      label: 'supervision.hub.queues_title'.tr(),
      value: '$total',
      caption: inQueues,
      segments: [
        for (final queue in queuesWithPending)
          SacStatusSegment(
            count: countOf(queue),
            color: SacTonePalette.of(context, queue.tone).solid,
            label: '${queue.shortTitle} ${countOf(queue)}',
          ),
      ],
    );
  }
}

/// Every queue is empty: the box gives way to a green panel.
class _AllClearPanel extends StatelessWidget {
  const _AllClearPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SacStatePanel(
        style: SacStatusStyle.of(context, SacStatusKind.validated, label: ''),
        title: 'supervision.hub.all_clear_title'.tr(),
        message: 'supervision.hub.all_clear_body'.tr(),
      ),
    );
  }
}

/// Same footprint as the summary box while the counts load.
class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    Widget bone(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c.border,
            borderRadius: BorderRadius.circular(AppTheme.radius2XS),
          ),
        );
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: SacSummaryBox(
          color: c.surfaceVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bone(96, 12),
              const SizedBox(height: 10),
              bone(64, 30),
              const SizedBox(height: 14),
              bone(double.infinity, 8),
              const SizedBox(height: 12),
              bone(160, 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Second line of a queue row: the pending count once it is known, «Al día»
/// when it is zero, the plain description when the server sent none. One line
/// tall in every state, so the row never jumps when the counts land.
class _QueueStatus extends StatelessWidget {
  const _QueueStatus({
    required this.loading,
    required this.count,
    required this.pendingLabel,
    required this.description,
  });

  final bool loading;
  final int? count;
  final String Function(int count) pendingLabel;
  final String description;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    const fontSize = SacFontSize.bodyMedium;
    const lineHeight = 1.3;
    final lineExtent =
        MediaQuery.textScalerOf(context).scale(fontSize) * lineHeight;

    Widget text(String value) => Text(
          value,
          key: ValueKey(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            height: lineHeight,
            color: c.textSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );

    final Widget line;
    if (loading) {
      line = ExcludeSemantics(
        key: const ValueKey('loading'),
        child: Container(
          width: 88,
          height: 10,
          decoration: BoxDecoration(
            color: c.border,
            borderRadius: BorderRadius.circular(AppTheme.radius2XS),
          ),
        ),
      );
    } else {
      final pending = count;
      line = switch (pending) {
        null => text(description),
        0 => const SupervisionAllClearLabel(key: ValueKey('all-clear')),
        _ => text(pendingLabel(pending)),
      };
    }

    return SizedBox(
      height: lineExtent,
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : SacMotion.switcher,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, if (current != null) current],
        ),
        child: line,
      ),
    );
  }
}

/// Footnote under the queues when the counts could not load. The rows above
/// stay usable.
class _CountsError extends StatelessWidget {
  const _CountsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    const buttonPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    final message = Row(
      children: [
        ExcludeSemantics(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 16,
            color: c.error,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'supervision.hub.counts_error'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              height: 1.35,
              color: c.textSecondary,
            ),
          ),
        ),
      ],
    );

    // With large text the button no longer fits beside the message.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            message,
            const SizedBox(height: 4),
            SacButton(
              text: 'common.retry'.tr(),
              variant: SacButtonVariant.ghost,
              fullWidth: true,
              labelMaxLines: 2,
              padding: buttonPadding,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 12, 0),
      child: Row(
        children: [
          Expanded(child: message),
          SacButton.ghost(
            text: 'common.retry'.tr(),
            onPressed: onRetry,
            padding: buttonPadding,
          ),
        ],
      ),
    );
  }
}

// ── "Tu territorio" ─────────────────────────────────────────────────────────

class _TerritorySection extends StatelessWidget {
  const _TerritorySection({required this.views});

  final List<_TerritoryView> views;

  @override
  Widget build(BuildContext context) {
    return SacGroupedSection(
      label: 'supervision.hub.territory_title'.tr(),
      // A count of rows says nothing here.
      action: const SizedBox.shrink(),
      children: [
        for (final view in views)
          SacListRow(
            leading: SacListRowIcon(view.icon, tone: SacTone.info),
            title: view.title,
            subtitle: view.description,
            onTap: () => context.push(view.route),
          ),
      ],
    );
  }
}

// ── Territory without configuration ─────────────────────────────────────────

/// Warning panel, a hint and (below, fixed) the «Comprobar de nuevo» action
/// that the hub passes to [_HubScroll.footer].
class _UnconfiguredTerritory extends StatelessWidget {
  const _UnconfiguredTerritory({required this.checkedWithoutChange});

  final bool checkedWithoutChange;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final warning = SacTonePalette.of(context, SacTone.warning);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: SacStatePanel(
            style: SacStatusStyle(
              kind: SacStatusKind.pending,
              container: warning.container,
              onContainer: warning.onContainer,
              solid: warning.solid,
              icon: HugeIcons.strokeRoundedLocation01,
              label: '',
            ),
            title: 'supervision.hub.unconfigured_title'.tr(),
            message: 'supervision.hub.unconfigured_body'.tr(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Text(
            'supervision.hub.unconfigured_hint'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              height: 1.4,
              color: c.textSecondary,
            ),
          ),
        ),
        if (checkedWithoutChange)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'supervision.hub.unconfigured_unchanged'.tr(),
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  height: 1.35,
                  color: c.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
