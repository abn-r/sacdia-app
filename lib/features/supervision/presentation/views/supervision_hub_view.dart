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
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';

/// Widest the hub lists grow on a tablet.
const double _kMaxContentWidth = 640;

const String _kUnconfiguredLevel = kUnconfiguredTerritoryLevel;

/// Root of the territorial supervision surface (Union / Division).
///
/// Two grouped lists: the queues that wait for a decision, each with its live
/// pending count, and the read-only views of the territory. A row exists only
/// when the server granted its capability. The counts load on their own: a
/// failure never blocks the way into a function.
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

    final queues = unconfigured ? const <_Queue>[] : _queuesFor(user);
    final views = unconfigured ? const <_TerritoryView>[] : _viewsFor(user);

    final Widget body;
    if (unconfigured) {
      body = _HubScroll(
        onRefresh: _recheckTerritory,
        fill: true,
        child: _UnconfiguredTerritory(
          checking: _rechecking,
          checkedWithoutChange: _recheckedWithoutChange,
          onCheck: _recheckTerritory,
        ),
      );
    } else if (queues.isEmpty && views.isEmpty) {
      body = _HubScroll(
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'router.nav.supervision'.tr(),
        subtitle: _levelLabel(level),
        frosted: true,
        automaticallyImplyLeading: false,
        // Without a club the hub is the dashboard home and there is no other
        // bell: the inbox opens from here.
        actions: [
          if (isSupervisorWithoutClub(user))
            _NotificationsAction(
              unreadCount: ref.watch(unreadNotificationsCountProvider),
            ),
        ],
      ),
      body: SacFrostedVeil(child: body),
    );
  }
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
  ),
  folders(
    icon: HugeIcons.strokeRoundedFolder01,
    route: RouteNames.supervisionFolders,
    key: 'folders',
  ),
  requests(
    icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
    route: RouteNames.supervisionRequests,
    key: 'requests',
  ),
  unionCamporees(
    icon: HugeIcons.strokeRoundedCampfire,
    route: RouteNames.supervisionUnionCamporees,
    key: 'union_camporees',
  );

  const _Queue({required this.icon, required this.route, required this.key});

  final HugeIconData icon;
  final String route;
  final String key;

  String get title => 'supervision.hub.$key.title'.tr();
  String get description => 'supervision.hub.$key.description'.tr();
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
    this.fill = false,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// Centers [child] in the viewport (empty and unconfigured states).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final bounded = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
        child: child,
      ),
    );
    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (fill)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(
                  top: SacTopBar.frostedInset(context),
                ),
                child: bounded,
              ),
            )
          else
            SliverPadding(
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.only(bottom: 32),
              ),
              sliver: SliverToBoxAdapter(
                child: Align(alignment: Alignment.topCenter, child: bounded),
              ),
            ),
        ],
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacGroupedSection(
          label: 'supervision.hub.queues_title'.tr(),
          count: counts == null ? null : _visibleTotal(counts),
          rollCount: true,
          // No total to show until the counts arrive.
          action: counts == null ? const SizedBox.shrink() : null,
          children: [
            for (final queue in queues)
              _HubRow(
                icon: queue.icon,
                title: queue.title,
                onTap: () => context.push(queue.route),
                subtitle: _QueueStatus(
                  loading: loading,
                  count: counts == null ? null : queue.countIn(counts),
                  pendingLabel: queue.pending,
                  description: queue.description,
                ),
              ),
          ],
        ),
        if (failed && counts == null) _CountsError(onRetry: onRetry),
      ],
    );
  }

  int _visibleTotal(SupervisionPendingCounts counts) {
    var total = 0;
    for (final queue in queues) {
      total += queue.countIn(counts) ?? 0;
    }
    return total;
  }
}

/// Second line of a queue row: the pending count once it is known, the plain
/// description when the server sent none. One line tall in every state, so the
/// row never jumps when the counts land.
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
      final (text, color, weight) = switch (pending) {
        null => (description, c.textSecondary, FontWeight.w400),
        0 => (
            'supervision.hub.up_to_date'.tr(),
            c.textTertiary,
            FontWeight.w400,
          ),
        _ => (pendingLabel(pending), c.text, FontWeight.w600),
      };
      line = Text(
        text,
        key: ValueKey(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          color: color,
          fontWeight: weight,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
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
            leading: SacListRowIcon(view.icon),
            title: view.title,
            subtitle: view.description,
            onTap: () => context.push(view.route),
          ),
      ],
    );
  }
}

// ── Row with a live second line ─────────────────────────────────────────────

/// Same metrics as [SacListRow], with a widget in the subtitle slot.
class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final HugeIconData icon;
  final String title;
  final Widget subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: SacInkWell(
          onTap: onTap,
          pressedScale: SacMotion.rowPressScale,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  SacListRowIcon(icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: SacFontSize.titleMedium,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        subtitle,
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 18,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Territory without configuration ─────────────────────────────────────────

class _UnconfiguredTerritory extends StatelessWidget {
  const _UnconfiguredTerritory({
    required this.checking,
    required this.checkedWithoutChange,
    required this.onCheck,
  });

  final bool checking;
  final bool checkedWithoutChange;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedLocation01,
              size: 56,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'supervision.hub.unconfigured_title'.tr(),
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontSize: SacFontSize.titleLarge,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'supervision.hub.unconfigured_body'.tr(),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: SacFontSize.titleSmall,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          // Bounded and flexible: the label wraps instead of overflowing on a
          // narrow screen or with large text.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: SacButton(
              text: 'supervision.hub.unconfigured_action'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              fullWidth: true,
              labelMaxLines: 2,
              isLoading: checking,
              onPressed: onCheck,
            ),
          ),
          if (checkedWithoutChange && !checking) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                'supervision.hub.unconfigured_unchanged'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  height: 1.35,
                  color: c.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Notifications action ────────────────────────────────────────────────────

class _NotificationsAction extends StatelessWidget {
  const _NotificationsAction({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SacPressable(
          listenOnly: true,
          child: IconButton(
            enableFeedback: false,
            onPressed: () => context.push(RouteNames.notificationsInbox),
            tooltip: 'dashboard.notifications_tooltip'.tr(),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedNotification01,
              size: 24,
              color: c.text,
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: c.error,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
                constraints: const BoxConstraints(minWidth: 16),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: textTheme.labelSmall?.copyWith(
                    color: c.onError,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
