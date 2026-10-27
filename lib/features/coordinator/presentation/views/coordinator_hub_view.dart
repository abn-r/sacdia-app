import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sacdia_app/core/animations/animated_counter.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/relative_time.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/instructor_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_stat_tile.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_club.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_scope.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/sla_dashboard.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/members/presentation/utils/consent_access.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/consent_review_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_reports_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/coordinator_reports_view.dart';

/// `when` that keeps showing stale data while a refresh/invalidation reloads,
/// so pull-to-refresh does not flash skeletons. After an error (no value) the
/// loading branch still runs, which gives retry visible feedback.
extension _SoftWhen<T> on AsyncValue<T> {
  R softWhen<R>({
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function() loading,
  }) =>
      when(
        skipLoadingOnReload: hasValue,
        data: data,
        error: error,
        loading: loading,
      );
}

/// Number of items previewed in the hub lists (oldest evidences, clubs).
const int _kPreviewCount = 3;

/// Stagger step between section cards.
const Duration _kStagger = Duration(milliseconds: 80);

/// Coordination tab root.
///
/// Answers "what needs me first": pending evidences (with the oldest three),
/// response-time KPIs and the clubs under the coordinator's scope. Each
/// section loads and fails on its own; only the scope gates the whole screen.
class CoordinatorHubView extends ConsumerWidget {
  const CoordinatorHubView({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(coordinatorScopeProvider);
    ref.invalidate(slaDashboardProvider);
    ref.invalidate(pendingEvidenceProvider);
    ref.invalidate(coordinatorClubsRawProvider);
    ref.invalidate(reportComplianceProvider);
    // Badge of the consent-forms entry (only read while the entry is shown).
    ref.invalidate(consentPendingCountProvider);

    Future<void> settle(Future<Object?> future) async {
      try {
        await future;
      } catch (_) {
        // Each section renders its own error state.
      }
    }

    await Future.wait([
      settle(ref.read(coordinatorScopeProvider.future)),
      settle(ref.read(slaDashboardProvider.future)),
      settle(ref.read(pendingEvidenceProvider(null).future)),
      settle(ref.read(coordinatorClubsRawProvider.future)),
      settle(ref.read(reportComplianceProvider(kWholeYearCompliance).future)),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final user = ref.watch(authNotifierProvider.select((v) => v.valueOrNull));
    final scopeAsync = ref.watch(coordinatorScopeProvider);
    final clubs = ref.watch(coordinatorClubsRawProvider).valueOrNull;
    final subtitle = scopeAsync.whenOrNull(
      data: (scope) => coordinatorScopeSubtitle(scope, clubsFallback: clubs),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'coordinator.hub.title'.tr(),
        subtitle: subtitle,
        frosted: true,
        automaticallyImplyLeading: false,
        titleIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedAnalytics01,
          size: 22,
          color: accent.color,
        ),
        // Without a club the hub is the dashboard home and there is no other
        // bell: the inbox opens from here.
        actions: [
          if (isCoordinatorWithoutClub(user))
            _NotificationsAction(
              unreadCount: ref.watch(unreadNotificationsCountProvider),
            ),
        ],
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => scopeAsync.softWhen(
            loading: () => _HubScroll(
              onRefresh: () => _refresh(ref),
              children: const [
                _SummarySkeleton(),
                SizedBox(height: 24),
                _StatsSkeleton(),
                SizedBox(height: 24),
                _ClubsSkeleton(),
              ],
            ),
            error: (error, _) => isCoordinatorForbidden(error)
                ? SacErrorState.forbidden(
                    padding: SacTopBar.paddingBelowBar(
                      context,
                      const EdgeInsets.all(32),
                    ),
                  )
                : SacErrorState(
                    title: 'coordinator.hub.error_title'.tr(),
                    message: 'coordinator.hub.error_message'.tr(),
                    onRetry: () => _refresh(ref),
                    padding: SacTopBar.paddingBelowBar(
                      context,
                      const EdgeInsets.all(32),
                    ),
                  ),
            data: (scope) {
              if (!scope.isCoordinator || !scope.hasAssignedSections) {
                return RefreshIndicator(
                  color: accent.color,
                  edgeOffset: SacTopBar.frostedInset(context),
                  onRefresh: () => _refresh(ref),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: SacTopBar.frostedInset(context),
                          ),
                          child: SacEmptyState(
                            icon: HugeIcons.strokeRoundedBuilding04,
                            title: 'coordinator.hub.empty_title'.tr(),
                            body: 'coordinator.hub.empty_body'.tr(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return _HubScroll(
                onRefresh: () => _refresh(ref),
                children: [
                  const _ReviewSection(),
                  // Consent forms of minors to verify: only for a coordinator
                  // role carrying `consent:verify` (what the server requires).
                  if (coordinatorRoleCanVerify(user)) ...const [
                    SizedBox(height: 24),
                    _ConsentSection(),
                  ],
                  const SizedBox(height: 24),
                  const _ResponseTimeSection(),
                  const SizedBox(height: 24),
                  const _ClubsSection(),
                  const SizedBox(height: 24),
                  const _ReportsSection(),
                ],
              );
            },
          ),
        ),
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
                  borderRadius: BorderRadius.circular(8),
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

// ── "Fichas por verificar" ──────────────────────────────────────────────────

/// Entry to the consent-forms verification queue, with the pending total as a
/// badge. Only built when the hub already decided the user may verify.
class _ConsentSection extends ConsumerWidget {
  const _ConsentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(coordinatorScopeProvider).valueOrNull;
    if (scope == null || !scope.hasAssignedSections) {
      return const SizedBox.shrink();
    }
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    // Cheap: asks for a single form, only to read the total.
    final count = ref.watch(consentPendingCountProvider).valueOrNull;

    return Semantics(
      container: true,
      child: SacCard(
        animate: true,
        // Back from the queue the total may have changed (forms were
        // verified): read it again.
        onTap: () async {
          await context.push(RouteNames.coordinatorConsentReview);
          if (context.mounted) ref.invalidate(consentPendingCountProvider);
        },
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFileVerified,
                size: 22,
                color: c.onWarning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'coordinator.nav.consent_title'.tr(),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'coordinator.nav.consent_subtitle'.tr(),
                    style:
                        textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 8),
              SacBadge.warning(label: count.toString()),
            ],
            const SizedBox(width: 8),
            const _Chevron(),
          ],
        ),
      ),
    );
  }
}

// ── Scope subtitle ──────────────────────────────────────────────────────────

/// "4 clubes · Distrito Norte" style summary of what the coordinator covers.
///
/// Club count comes from the distinct `clubId`s of the scope sections (falling
/// back to [clubsFallback] when sections carry no club id). The place part is
/// the district name when there is exactly one, otherwise the number of
/// districts; when no district is exposed it falls back to the local field.
/// Returns null when there is nothing to say.
@visibleForTesting
String? coordinatorScopeSubtitle(
  CoordinatorScope scope, {
  List<CoordinatorClub>? clubsFallback,
}) {
  if (!scope.hasAssignedSections) return null;

  Set<String> distinct(Iterable<String?> values) => {
        for (final v in values)
          if (v != null && v.trim().isNotEmpty) v.trim(),
      };

  final sectionClubIds = {
    for (final s in scope.sections)
      if (s.clubId != null) s.clubId,
  };
  final clubCount =
      sectionClubIds.isNotEmpty ? sectionClubIds.length : clubsFallback?.length;

  final districts = distinct(scope.sections.map((s) => s.districtName));
  final fields = distinct(scope.sections.map((s) => s.localFieldName));

  String? place;
  if (districts.length == 1) {
    place = districts.first;
  } else if (districts.length > 1) {
    place = 'coordinator.hub.scope.districts_other'
        .tr(namedArgs: {'count': '${districts.length}'});
  } else if (fields.length == 1) {
    place = fields.first;
  } else if (fields.length > 1) {
    place = 'coordinator.hub.scope.fields_other'
        .tr(namedArgs: {'count': '${fields.length}'});
  }

  String? clubsLabel;
  if (clubCount != null && clubCount > 0) {
    clubsLabel = (clubCount == 1
            ? 'coordinator.hub.scope.clubs_one'
            : 'coordinator.hub.scope.clubs_other')
        .tr(namedArgs: {'count': '$clubCount'});
  }

  final parts = [clubsLabel, place].whereType<String>().toList();
  return parts.isEmpty ? null : parts.join(' · ');
}

// ── Scroll scaffold ─────────────────────────────────────────────────────────

class _HubScroll extends StatelessWidget {
  const _HubScroll({required this.onRefresh, required this.children});

  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: SacTopBar.paddingBelowBar(
              context,
              EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
            ),
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ],
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final showAction = actionLabel != null && onAction != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
            ),
            if (showAction)
              SacPressable(
                onTap: onAction,
                semanticLabel: actionLabel,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: Text(
                      actionLabel!,
                      style: textTheme.labelLarge?.copyWith(
                        color: SacAccent.of(context).color,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared bits ─────────────────────────────────────────────────────────────

class _Bone extends StatelessWidget {
  const _Bone({this.width, required this.height, this.circle = false});

  final double? width;
  final double height;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.sac.border,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(6),
      ),
    );
  }
}

/// Compact inline error that keeps the section visible and retryable.
class _SectionError extends StatelessWidget {
  const _SectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 20,
            color: c.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'coordinator.hub.section_error'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          SacButton.ghost(
            text: 'common.retry'.tr(),
            onPressed: onRetry,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: HugeIcons.strokeRoundedArrowRight01,
      size: 18,
      color: context.sac.textTertiary,
    );
  }
}

/// Days with at most one decimal, in the UI locale ("2,5" in es, "2.5" in en).
String _formatDays(BuildContext context, double days) => intl.NumberFormat(
      '0.#',
      Localizations.maybeLocaleOf(context)?.toString(),
    ).format((days * 10).round() / 10);

// ── "Por revisar" ───────────────────────────────────────────────────────────

class _ReviewSection extends ConsumerWidget {
  const _ReviewSection();

  void _openList(BuildContext context) =>
      context.push(RouteNames.coordinatorEvidenceReview);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slaAsync = ref.watch(slaDashboardProvider);
    final pendingAsync = ref.watch(pendingEvidenceProvider(null));

    // The queue total is the count of the list "Ver todas" opens; the SLA
    // dashboard adds overdue and average days, and its own pending count
    // stands in until the queue answers.
    final queueTotal = pendingAsync.valueOrNull?.total;
    final pending = queueTotal ?? slaAsync.valueOrNull?.evidence.pending;
    final allClear = pending == 0;

    final children = <Widget>[];
    var index = 0;

    if (allClear) {
      children.add(const _AllClearCard());
    } else {
      children.add(
        slaAsync.softWhen(
          loading: () => const _SummarySkeleton(showHeader: false),
          error: (_, __) => _SectionError(
            onRetry: () => ref.invalidate(slaDashboardProvider),
          ),
          data: (sla) => _ReviewSummaryCard(
            stat: sla.evidence,
            pending: queueTotal ?? sla.evidence.pending,
            onTap: () => _openList(context),
          ),
        ),
      );
      index++;
      children.add(const SizedBox(height: 12));
      children.add(
        pendingAsync.softWhen(
          loading: () => const _PreviewRowsSkeleton(),
          error: (_, __) => _SectionError(
            onRetry: () => ref.invalidate(pendingEvidenceProvider),
          ),
          data: (queue) {
            if (queue.items.isEmpty) return const SizedBox.shrink();
            final oldest = [...queue.items]
              ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
            return _OldestPreview(
              items: oldest.take(_kPreviewCount).toList(),
              delay: _kStagger * index,
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'coordinator.hub.review.title'.tr(),
          actionLabel: 'coordinator.hub.review.see_all'.tr(),
          onAction: () => _openList(context),
        ),
        ...children,
      ],
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({
    required this.stat,
    required this.pending,
    required this.onTap,
  });

  final SlaStat stat;

  /// Evidences waiting for review.
  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final label = (pending == 1
            ? 'coordinator.hub.review.label_one'
            : 'coordinator.hub.review.label_other')
        .tr();

    return SacCard(
      onTap: onTap,
      animate: true,
      child: Row(
        children: [
          AnimatedCounter(
            value: pending,
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                if (stat.overdue > 0 || stat.avgDays > 0) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (stat.overdue > 0)
                        SacBadge.error(
                          icon: HugeIcons.strokeRoundedAlert02,
                          label: (stat.overdue == 1
                                  ? 'coordinator.hub.review.overdue_one'
                                  : 'coordinator.hub.review.overdue_other')
                              .tr(namedArgs: {'count': '${stat.overdue}'}),
                        ),
                      if (stat.avgDays > 0)
                        SacBadge(
                          variant: SacBadgeVariant.neutral,
                          icon: HugeIcons.strokeRoundedClock01,
                          label: 'coordinator.hub.review.avg_days'.tr(
                            namedArgs: {
                              'days': _formatDays(context, stat.avgDays)
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _Chevron(),
        ],
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;

    return SacCard(
      animate: true,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              size: 22,
              color: c.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'coordinator.hub.review.all_clear'.tr(),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'coordinator.hub.review.all_clear_body'.tr(),
                  style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OldestPreview extends StatelessWidget {
  const _OldestPreview({required this.items, required this.delay});

  final List<EvidenceReviewItem> items;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'coordinator.hub.review.oldest_first'.tr(),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: c.textSecondary),
          ),
        ),
        SacCard(
          padding: EdgeInsets.zero,
          animate: true,
          animationDelay: delay,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: c.border),
                _EvidencePreviewRow(item: items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EvidencePreviewRow extends StatelessWidget {
  const _EvidencePreviewRow({required this.item});

  final EvidenceReviewItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final age = formatRelativeTime(item.submittedAt.toLocal());
    final detail = [
      if (item.context != null && item.context!.trim().isNotEmpty)
        item.context!.trim(),
      age,
    ].join(' · ');

    return SacInkWell(
      onTap: () => context.push(
        RouteNames.coordinatorEvidenceReviewDetail(
          item.type.apiValue,
          item.id,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              InstructorAvatar(
                name: item.displayMemberName,
                photoUrl: item.memberPhotoUrl,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayMemberName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          textTheme.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _Chevron(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── "Tiempo de respuesta" ───────────────────────────────────────────────────

class _ResponseTimeSection extends ConsumerWidget {
  const _ResponseTimeSection();

  void _openSla(BuildContext context) =>
      context.push(RouteNames.coordinatorSla);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slaAsync = ref.watch(slaDashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'coordinator.hub.sla.title'.tr(),
          actionLabel: 'coordinator.hub.sla.see_detail'.tr(),
          onAction: () => _openSla(context),
        ),
        slaAsync.softWhen(
          loading: () => const _StatsSkeleton(showHeader: false),
          error: (_, __) => _SectionError(
            onRetry: () => ref.invalidate(slaDashboardProvider),
          ),
          data: (sla) {
            final stat = sla.evidence;
            void open() => _openSla(context);
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SacStatTile(
                      icon: HugeIcons.strokeRoundedFolder01,
                      value: stat.pending,
                      label: 'coordinator.sla.stat.pending'.tr(),
                      tone: stat.pending > 0
                          ? SacStatTone.accent
                          : SacStatTone.neutral,
                      onTap: open,
                      animate: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SacStatTile(
                      icon: HugeIcons.strokeRoundedClock01,
                      value: stat.avgDays,
                      decimals: 1,
                      label: 'coordinator.sla.stat.avg_days'.tr(),
                      onTap: open,
                      animate: true,
                      animationDelay: _kStagger,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SacStatTile(
                      icon: HugeIcons.strokeRoundedAlert02,
                      value: stat.overdue,
                      label: 'coordinator.sla.stat.overdue'.tr(),
                      tone: stat.overdue > 0
                          ? SacStatTone.error
                          : SacStatTone.neutral,
                      onTap: open,
                      animate: true,
                      animationDelay: _kStagger * 2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── "Mis clubes" ────────────────────────────────────────────────────────────

class _ClubsSection extends ConsumerWidget {
  const _ClubsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(coordinatorClubsRawProvider);
    final count = clubsAsync.valueOrNull?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'coordinator.hub.clubs.title'.tr(),
          actionLabel: count > 0
              ? 'coordinator.hub.clubs.see_all'
                  .tr(namedArgs: {'count': '$count'})
              : null,
          onAction: count > 0
              ? () => context.push(RouteNames.coordinatorClubs)
              : null,
        ),
        clubsAsync.softWhen(
          loading: () => const _ClubsSkeleton(showHeader: false),
          error: (_, __) => _SectionError(
            onRetry: () => ref.invalidate(coordinatorClubsRawProvider),
          ),
          data: (clubs) {
            if (clubs.isEmpty) {
              return SacCard(
                child: Text(
                  'coordinator.hub.clubs.empty'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: context.sac.textSecondary),
                ),
              );
            }
            final preview = clubs.take(_kPreviewCount).toList();
            return Column(
              children: [
                for (var i = 0; i < preview.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ClubRow(club: preview[i], delay: _kStagger * i),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ClubRow extends StatelessWidget {
  const _ClubRow({required this.club, required this.delay});

  final CoordinatorClub club;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final textTheme = Theme.of(context).textTheme;
    final location = [club.districtName, club.localFieldName]
        .map((v) => v?.trim())
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    final sectionTypes = <String>{
      for (final s in club.sections) s.displayName,
    }.toList();
    final initial =
        club.name.trim().isEmpty ? '?' : club.name.trim()[0].toUpperCase();

    return SacCard(
      animate: true,
      animationDelay: delay,
      // Sin onTap: el coordinador no puede abrir /club/:id (router y API 403).
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.light,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: Text(
                initial,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent.dark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                if (location != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
                if (sectionTypes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final type in sectionTypes)
                        SacBadge(
                          label: type,
                          variant: SacBadgeVariant.neutral,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── "Reportes" ─────────────────────────────────────────────────────────────

class _ReportsSection extends ConsumerWidget {
  const _ReportsSection();

  void _openReports(BuildContext context) =>
      context.push(RouteNames.coordinatorReports);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complianceAsync =
        ref.watch(reportComplianceProvider(kWholeYearCompliance));
    final forbidden = complianceAsync.hasError &&
        !complianceAsync.isLoading &&
        isCoordinatorForbidden(complianceAsync.error!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'coordinator.hub.reports.title'.tr(),
          actionLabel:
              forbidden ? null : 'coordinator.hub.reports.see_all'.tr(),
          onAction: forbidden ? null : () => _openReports(context),
        ),
        if (forbidden)
          SacCard(
            backgroundColor: context.sac.surfaceVariant,
            child: Text(
              'coordinator.hub.reports.forbidden'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.sac.textSecondary),
            ),
          )
        else
          complianceAsync.softWhen(
            loading: () => const _StatsSkeleton(showHeader: false),
            error: (_, __) => _SectionError(
              onRetry: () => ref.invalidate(reportComplianceProvider),
            ),
            data: (compliance) => ComplianceStatTiles(
              counts: compliance.overall,
              onTap: () => _openReports(context),
            ),
          ),
      ],
    );
  }
}

// ── Skeletons (match the real layouts) ──────────────────────────────────────

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton({this.showHeader = true});

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            _SectionHeader(title: 'coordinator.hub.review.title'.tr()),
          const SacCard(
            child: Row(
              children: [
                _Bone(width: 44, height: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bone(width: 140, height: 14),
                      SizedBox(height: 10),
                      _Bone(width: 96, height: 22),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showHeader) ...[
            const SizedBox(height: 12),
            const _PreviewRowsSkeleton(),
          ],
        ],
      ),
    );
  }
}

class _PreviewRowsSkeleton extends StatelessWidget {
  const _PreviewRowsSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ExcludeSemantics(
      child: SacCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < _kPreviewCount; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: c.border),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _Bone(width: 40, height: 40, circle: true),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Bone(width: 150, height: 14),
                          SizedBox(height: 6),
                          _Bone(width: 110, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton({this.showHeader = true});

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) _SectionHeader(title: 'coordinator.hub.sla.title'.tr()),
        const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: SacStatTile.skeleton()),
              SizedBox(width: 10),
              Expanded(child: SacStatTile.skeleton()),
              SizedBox(width: 10),
              Expanded(child: SacStatTile.skeleton()),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClubsSkeleton extends StatelessWidget {
  const _ClubsSkeleton({this.showHeader = true});

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            _SectionHeader(title: 'coordinator.hub.clubs.title'.tr()),
          for (var i = 0; i < _kPreviewCount; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            const SacCard(
              child: Row(
                children: [
                  _Bone(width: 44, height: 44),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bone(width: 160, height: 14),
                        SizedBox(height: 6),
                        _Bone(width: 110, height: 12),
                        SizedBox(height: 8),
                        _Bone(width: 84, height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
