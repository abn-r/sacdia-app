import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_operations.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_operations_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_breadcrumb.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_operations_sections.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_scroll.dart';

/// Indicators of a territory and of what sits right below it.
///
/// With an empty [query] the server answers for the actor's own territory.
/// Opening a row pushes this same screen one level down, so going back
/// climbs one level at a time.
class SupervisionOperationsView extends ConsumerWidget {
  const SupervisionOperationsView({
    super.key,
    this.query = const SupervisionOperationsQuery(),
  });

  final SupervisionOperationsQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final provider = supervisionOperationsProvider(query);
    final async = ref.watch(provider);
    // A failed refresh keeps the last dashboard on screen.
    final dashboard = async.value;

    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {
        // The body renders the error.
      }
    }

    final Widget body;
    if (dashboard == null && async.hasError) {
      body = SupervisionScroll(
        onRefresh: refresh,
        fill: true,
        child: isForbiddenFailure(async.error!)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'supervision.operations.error_title'.tr(),
                message: 'supervision.operations.error_message'.tr(),
                onRetry: refresh,
              ),
      );
    } else if (dashboard == null) {
      body = SupervisionScroll(
        onRefresh: refresh,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: SacSkeletonList(
            itemCount: 6,
            leading: false,
            scrollable: false,
          ),
        ),
      );
    } else if (dashboard.summary.clubsTotal == 0 &&
        dashboard.children.isEmpty) {
      body = SupervisionScroll(
        onRefresh: refresh,
        fill: true,
        child: SacEmptyState(
          icon: HugeIcons.strokeRoundedAnalytics01,
          title: 'supervision.operations.empty_title'.tr(),
          body: 'supervision.operations.empty_body'.tr(),
        ),
      );
    } else {
      final user = ref.watch(authNotifierProvider.select((v) => v.value));
      body = SupervisionScroll(
        onRefresh: refresh,
        child: _Dashboard(
          dashboard: dashboard,
          crumbs: query.isOwnScope
              ? const []
              : _crumbsFor(
                  context,
                  dashboard,
                  user?.authorization?.territory?.level,
                ),
          canOpenClubs: hasCapability(user, 'clubs.view_territory'),
        ),
      );
    }

    final scopeName = dashboard?.scope.name.trim() ?? '';
    final ownTitle = 'supervision.operations.title'.tr();
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        // One level down the territory is the subject of the screen.
        title: query.isOwnScope || scopeName.isEmpty ? ownTitle : scopeName,
        subtitle: query.isOwnScope
            ? (scopeName.isEmpty ? null : scopeName)
            : _levelLabel(dashboard?.scope.level),
        frosted: true,
      ),
      body: SacFrostedVeil(child: body),
    );
  }
}

String? _levelLabel(SupervisionTerritoryLevel? level) => switch (level) {
      SupervisionTerritoryLevel.division =>
        'supervision.operations.level_division'.tr(),
      SupervisionTerritoryLevel.union =>
        'supervision.operations.level_union'.tr(),
      SupervisionTerritoryLevel.localField =>
        'supervision.operations.level_local_field'.tr(),
      SupervisionTerritoryLevel.club =>
        'supervision.operations.level_club'.tr(),
      _ => null,
    };

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.dashboard,
    required this.crumbs,
    required this.canOpenClubs,
  });

  final SupervisionOperationsDashboard dashboard;

  /// Path of the drilled-in territory; empty at the actor's own level.
  final List<SupervisionCrumb> crumbs;
  final bool canOpenClubs;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final summary = dashboard.summary;
    final yearLabel = _yearLabel(dashboard.period);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (crumbs.isNotEmpty)
          SupervisionBreadcrumb(
            crumbs: crumbs,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          ),
        SupervisionOperationsReportsBox(
          summary: summary,
          period: dashboard.period,
        ),
        SupervisionOperationsFigures(summary: summary),
        if (dashboard.children.isNotEmpty)
          SupervisionOperationsChildren(
            children: dashboard.children,
            canOpenClubs: canOpenClubs,
          ),
        SupervisionOperationsPeriodFacts(summary: summary),
        if (yearLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(
              'supervision.operations.year_note'.tr(args: [yearLabel]),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                height: 1.3,
                color: c.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

/// "2026", or "2026-2027" when the ecclesiastical year crosses a new year.
String? _yearLabel(SupervisionOperationsPeriod period) {
  final start = period.yearStart?.year;
  final end = period.yearEnd?.year;
  if (start == null && end == null) return null;
  if (start == null || end == null || start == end) return '${start ?? end}';
  return '$start-$end';
}

/// Position of a level in the drill-down: division, union, local field.
int? _depthOf(SupervisionTerritoryLevel? level) => switch (level) {
      SupervisionTerritoryLevel.division => 0,
      SupervisionTerritoryLevel.union => 1,
      SupervisionTerritoryLevel.localField => 2,
      _ => null,
    };

/// Same ladder for the actor's own territory (`authorization.territory.level`).
/// A level above the divisions (`all`) sits one step over the first one.
int _ownDepth(String? level) => switch (level) {
      'division' => 0,
      'union' => 1,
      'local_field' => 2,
      _ => -1,
    };

/// Ancestors the actor can climb back to, then the territory on screen.
///
/// Opening a row pushes this same screen one level down, so the screen of an
/// ancestor is [current depth - ancestor depth] pops away. Levels above the
/// actor's own territory are not on the stack and are left out.
List<SupervisionCrumb> _crumbsFor(
  BuildContext context,
  SupervisionOperationsDashboard dashboard,
  String? ownLevel,
) {
  final scope = dashboard.scope;
  final currentDepth = _depthOf(scope.level);
  final ownDepth = _ownDepth(ownLevel);
  final crumbs = <SupervisionCrumb>[];
  if (currentDepth != null) {
    for (final node in scope.path) {
      final depth = _depthOf(node.level);
      final name = node.name.trim();
      if (depth == null || name.isEmpty || depth >= currentDepth) continue;
      // The first screen of the stack is the actor's own territory.
      if (depth < ownDepth) continue;
      final pops = currentDepth - depth;
      crumbs.add(
        SupervisionCrumb(
          label: name,
          onTap: () {
            var left = pops;
            Navigator.of(context).popUntil((route) => left-- <= 0);
          },
        ),
      );
    }
  }
  if (crumbs.isEmpty) return const [];
  return [...crumbs, SupervisionCrumb(label: scope.name.trim())];
}
