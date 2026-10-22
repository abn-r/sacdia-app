import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/coordinator_bone.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/evidence_review_card.dart';

/// Cards that get the staggered entrance; later ones appear without delay so
/// scrolling a long queue never replays animations.
const int _kStaggeredCards = 6;

/// Skeleton cards shown while the queue loads.
const int _kSkeletonCards = 4;

/// Pending evidence queue, oldest first, filterable by type.
///
/// Requires the coordinator or admin role on the backend. The queue loads one
/// page at a time: reaching the end of the list asks for the next one. Pull to
/// refresh reloads from the first page; approving or rejecting in the detail
/// invalidates [pendingEvidenceProvider], so the list is fresh when the user
/// comes back.
class EvidenceReviewListView extends ConsumerWidget {
  const EvidenceReviewListView({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    final filter = ref.read(evidenceTypeFilterProvider);
    ref.invalidate(pendingEvidenceProvider);
    try {
      await ref.read(pendingEvidenceProvider(filter).future);
    } catch (_) {
      // The error state renders the failure.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final filter = ref.watch(evidenceTypeFilterProvider);
    final evidenceAsync = ref.watch(pendingEvidenceProvider(filter));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'coordinator.evidence_review.list.title'.tr(),
        frosted: true,
        titleIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedTaskDone01,
          size: 22,
          color: accent.color,
        ),
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: evidenceAsync.when(
              skipLoadingOnReload: evidenceAsync.hasValue,
              loading: () => _QueueScroll(
                onRefresh: () => _refresh(ref),
                slivers: const [_SkeletonSliver()],
              ),
              error: (error, _) => isCoordinatorForbidden(error)
                  ? SacErrorState.forbidden(
                      padding: SacTopBar.paddingBelowBar(
                        context,
                        const EdgeInsets.all(32),
                      ),
                    )
                  : SacErrorState(
                      title:
                          'coordinator.evidence_review.list.error_title'.tr(),
                      message:
                          'coordinator.evidence_review.list.error_message'.tr(),
                      onRetry: () => ref.invalidate(pendingEvidenceProvider),
                      padding: SacTopBar.paddingBelowBar(
                        context,
                        const EdgeInsets.all(32),
                      ),
                    ),
              data: (queue) {
                final items = queue.items;
                if (items.isEmpty) {
                  return _QueueScroll(
                    onRefresh: () => _refresh(ref),
                    slivers: [_EmptySliver(filtered: filter != null)],
                  );
                }
                // The backend already returns the oldest first; sorting here
                // guarantees it whatever the server order is.
                final oldestFirst = [...items]
                  ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
                return _QueueScroll(
                  onRefresh: () => _refresh(ref),
                  slivers: [
                    _ItemsSliver(
                      items: oldestFirst,
                      footer: queue.hasMore
                          ? _LoadMoreFooter(
                              queue: queue,
                              onLoadMore: () => ref
                                  .read(
                                      pendingEvidenceProvider(filter).notifier)
                                  .loadMore(),
                            )
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scroll scaffold ───────────────────────────────────────────────────────────

/// Pull-to-refresh scroll with the type filter on top of whatever [slivers]
/// the current state needs. The filter scrolls with the content (like the hub)
/// so it never sits under the frosted bar.
class _QueueScroll extends StatelessWidget {
  const _QueueScroll({required this.onRefresh, required this.slivers});

  final Future<void> Function() onRefresh;
  final List<Widget> slivers;

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
              EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
            ),
            sliver: const SliverToBoxAdapter(child: _FilterChips()),
          ),
          ...slivers,
        ],
      ),
    );
  }
}

// ── Items ─────────────────────────────────────────────────────────────────────

class _ItemsSliver extends StatelessWidget {
  const _ItemsSliver({required this.items, this.footer});

  final List<EvidenceReviewItem> items;

  /// Built lazily after the last card, so it only exists once the end of the
  /// list is near the viewport.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 32),
      sliver: SliverList.builder(
        itemCount: items.length + (footer == null ? 1 : 2),
        itemBuilder: (context, index) {
          if (index == items.length + 1) return footer!;
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'coordinator.evidence_review.list.oldest_first'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: c.textSecondary),
              ),
            );
          }
          final cardIndex = index - 1;
          final item = items[cardIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: EvidenceReviewCard(
              item: item,
              animate: cardIndex < _kStaggeredCards,
              animationDelay: SacMotion.stagger * cardIndex,
              onTap: () => context.push(
                RouteNames.coordinatorEvidenceReviewDetail(
                  item.type.apiValue,
                  item.id,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// End of a queue with more pages: asks for the next page as soon as it is
/// built (the list builds it lazily, near the viewport) and shows the
/// progress or a retry if that page failed.
class _LoadMoreFooter extends StatefulWidget {
  const _LoadMoreFooter({required this.queue, required this.onLoadMore});

  final PendingEvidenceState queue;
  final VoidCallback onLoadMore;

  @override
  State<_LoadMoreFooter> createState() => _LoadMoreFooterState();
}

class _LoadMoreFooterState extends State<_LoadMoreFooter> {
  @override
  void initState() {
    super.initState();
    _maybeLoadMore();
  }

  @override
  void didUpdateWidget(covariant _LoadMoreFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoadMore();
  }

  /// A failed page waits for the retry button instead of looping.
  void _maybeLoadMore() {
    final queue = widget.queue;
    if (!queue.hasMore || queue.isLoadingMore || queue.loadMoreFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    if (widget.queue.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              'coordinator.evidence_review.list.load_more_error'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 4),
            SacButton.ghost(
              text: 'common.retry'.tr(),
              onPressed: widget.onLoadMore,
            ),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: SacLoadingSmall()),
    );
  }
}

class _EmptySliver extends StatelessWidget {
  const _EmptySliver({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: SacEmptyState(
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        title: (filtered
                ? 'coordinator.evidence_review.list.empty_filtered_title'
                : 'coordinator.evidence_review.list.empty_title')
            .tr(),
        body: (filtered
                ? 'coordinator.evidence_review.list.empty_filtered_body'
                : 'coordinator.evidence_review.list.empty_body')
            .tr(),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SkeletonSliver extends StatelessWidget {
  const _SkeletonSliver();

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 32),
      sliver: SliverToBoxAdapter(
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10, top: 2),
                child: CoordinatorBone(width: 110, height: 12),
              ),
              for (var i = 0; i < _kSkeletonCards; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                const _CardSkeleton(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Matches [EvidenceReviewCard]: avatar, three text lines and the badge row.
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SacCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoordinatorBone(width: 44, height: 44, circle: true),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoordinatorBone(width: 150, height: 14),
                SizedBox(height: 8),
                CoordinatorBone(width: 190, height: 12),
                SizedBox(height: 6),
                CoordinatorBone(width: 130, height: 12),
                SizedBox(height: 12),
                Row(
                  children: [
                    CoordinatorBone(width: 76, height: 24, radius: 12),
                    SizedBox(width: 8),
                    CoordinatorBone(width: 64, height: 24, radius: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterChips extends ConsumerWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(evidenceTypeFilterProvider);

    // Each chip shows the server total for its filter. Watching every filter
    // loads its first page, which also makes switching chips instant. No
    // count (null) while it loads, if it failed or if the server omitted it.
    int? total(EvidenceReviewType? type) => ref.watch(
          pendingEvidenceProvider(type).select((q) => q.valueOrNull?.total),
        );

    final filters = <({String label, EvidenceReviewType? value, int? count})>[
      (
        label: 'coordinator.evidence_review.list.filter_all'.tr(),
        value: null,
        count: total(null),
      ),
      (
        label: 'coordinator.evidence_review.list.filter_classes'.tr(),
        value: EvidenceReviewType.classType,
        count: total(EvidenceReviewType.classType),
      ),
      (
        label: 'coordinator.evidence_review.list.filter_honors'.tr(),
        value: EvidenceReviewType.honor,
        count: total(EvidenceReviewType.honor),
      ),
    ];

    return SizedBox(
      height: SacFilterChip.barHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          return SacFilterChip(
            label: filter.label,
            count: filter.count,
            selected: activeFilter == filter.value,
            onTap: () => ref.read(evidenceTypeFilterProvider.notifier).state =
                filter.value,
          );
        },
      ),
    );
  }
}
