import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_club.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/coordinator_bone.dart';

/// Cards that get the staggered entrance; later ones appear without delay.
const int _kStaggeredCards = 6;

/// Skeleton cards shown while the clubs load.
const int _kSkeletonCards = 6;

/// "Mis clubes" of the coordinator: every club in scope, searchable by name.
///
/// Tapping a card opens the club detail. Pull to refresh reloads the list.
class CoordinatorClubsListView extends ConsumerWidget {
  const CoordinatorClubsListView({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(coordinatorClubsRawProvider);
    try {
      await ref.read(coordinatorClubsRawProvider.future);
    } catch (_) {
      // The error state renders the failure.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final rawAsync = ref.watch(coordinatorClubsRawProvider);
    final clubsAsync = ref.watch(coordinatorClubsProvider);
    final total = rawAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'coordinator.clubs.title'.tr(),
        subtitle: total > 0
            ? (total == 1
                    ? 'coordinator.hub.scope.clubs_one'
                    : 'coordinator.hub.scope.clubs_other')
                .tr(namedArgs: {'count': '$total'})
            : null,
        frosted: true,
        titleIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedBuilding04,
          size: 22,
          color: accent.color,
        ),
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: rawAsync.when(
              skipLoadingOnReload: rawAsync.hasValue,
              loading: () => _ClubsScroll(
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
                      title: 'coordinator.clubs.error_title'.tr(),
                      message: 'coordinator.clubs.error_message'.tr(),
                      onRetry: () =>
                          ref.invalidate(coordinatorClubsRawProvider),
                      padding: SacTopBar.paddingBelowBar(
                        context,
                        const EdgeInsets.all(32),
                      ),
                    ),
              data: (all) {
                final clubs = clubsAsync.valueOrNull ?? all;
                if (all.isEmpty) {
                  // Nothing assigned: no search bar, there is nothing to find.
                  return _EmptyScroll(
                    onRefresh: () => _refresh(ref),
                    child: SacEmptyState(
                      icon: HugeIcons.strokeRoundedBuilding04,
                      title: 'coordinator.clubs.empty_title'.tr(),
                      body: 'coordinator.clubs.empty_subtitle'.tr(),
                    ),
                  );
                }
                return _ClubsScroll(
                  onRefresh: () => _refresh(ref),
                  slivers: [
                    if (clubs.isEmpty)
                      const _NoResultsSliver()
                    else
                      _ClubsSliver(clubs: clubs),
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

// ── Scroll scaffolds ──────────────────────────────────────────────────────────

/// Pull-to-refresh scroll with the search field on top of [slivers]. The field
/// scrolls with the content so it never sits under the frosted bar.
class _ClubsScroll extends StatelessWidget {
  const _ClubsScroll({required this.onRefresh, required this.slivers});

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
              EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
            ),
            sliver: const SliverToBoxAdapter(child: _ClubSearchField()),
          ),
          ...slivers,
        ],
      ),
    );
  }
}

class _EmptyScroll extends StatelessWidget {
  const _EmptyScroll({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search ────────────────────────────────────────────────────────────────────

class _ClubSearchField extends ConsumerStatefulWidget {
  const _ClubSearchField();

  @override
  ConsumerState<_ClubSearchField> createState() => _ClubSearchFieldState();
}

class _ClubSearchFieldState extends ConsumerState<_ClubSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(coordinatorClubSearchProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(coordinatorClubSearchProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) => SacTextField(
        controller: _controller,
        hint: 'coordinator.clubs.search_hint'.tr(),
        prefixIcon: HugeIcons.strokeRoundedSearch01,
        textInputAction: TextInputAction.search,
        onChanged: (text) =>
            ref.read(coordinatorClubSearchProvider.notifier).state = text,
        suffix: value.text.isEmpty
            ? null
            : SacPressable(
                listenOnly: true,
                child: IconButton(
                  enableFeedback: false,
                  tooltip: 'common.clear'.tr(),
                  onPressed: _clear,
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 18,
                    color: c.textTertiary,
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Clubs list ────────────────────────────────────────────────────────────────

class _ClubsSliver extends StatelessWidget {
  const _ClubsSliver({required this.clubs});

  final List<CoordinatorClub> clubs;

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
      sliver: SliverList.separated(
        itemCount: clubs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _ClubCard(
          club: clubs[index],
          animate: index < _kStaggeredCards,
          animationDelay: SacMotion.stagger * index,
        ),
      ),
    );
  }
}

class _NoResultsSliver extends ConsumerWidget {
  const _NoResultsSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(coordinatorClubSearchProvider).trim();
    return SliverFillRemaining(
      hasScrollBody: false,
      child: SacEmptyState(
        icon: HugeIcons.strokeRoundedSearch01,
        title: 'coordinator.clubs.empty_search_title'.tr(),
        body: 'coordinator.clubs.empty_search_body'
            .tr(namedArgs: {'query': query}),
      ),
    );
  }
}

// ── Club card ─────────────────────────────────────────────────────────────────

class _ClubCard extends StatelessWidget {
  const _ClubCard({
    required this.club,
    required this.animate,
    required this.animationDelay,
  });

  final CoordinatorClub club;
  final bool animate;
  final Duration animationDelay;

  /// "District · Local field", skipping what the backend did not send. Falls
  /// back to the local field id when there is no name for it.
  String get _location {
    final parts = <String>[
      if (club.districtName != null && club.districtName!.trim().isNotEmpty)
        club.districtName!.trim(),
      if (club.localFieldName != null && club.localFieldName!.trim().isNotEmpty)
        club.localFieldName!.trim()
      else if (club.localFieldId > 0)
        'coordinator.clubs.field_id_label'
            .tr(namedArgs: {'id': '${club.localFieldId}'}),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final textTheme = Theme.of(context).textTheme;
    final location = _location;
    final sectionTypes = <String>{
      for (final s in club.sections)
        if (s.displayName.trim().isNotEmpty) s.displayName.trim(),
    }.toList();
    final name = club.name.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return SacCard(
      animate: animate,
      animationDelay: animationDelay,
      // Sin onTap: el detalle de club (/club/:id) es de los miembros; el router
      // y la API (403) se lo niegan al coordinador, así que el toque no llevaba
      // a ninguna parte.
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.light,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    location,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
                if (sectionTypes.isNotEmpty) ...[
                  const SizedBox(height: 8),
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

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SkeletonSliver extends StatelessWidget {
  const _SkeletonSliver();

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
      sliver: SliverToBoxAdapter(
        child: ExcludeSemantics(
          child: Column(
            children: [
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

/// Matches [_ClubCard]: initial tile, name, location and section badges.
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SacCard(
      child: Row(
        children: [
          CoordinatorBone(
            width: 48,
            height: 48,
            radius: AppTheme.radiusSM,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoordinatorBone(width: 170, height: 16),
                SizedBox(height: 8),
                CoordinatorBone(width: 120, height: 12),
                SizedBox(height: 10),
                CoordinatorBone(width: 96, height: 24, radius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
