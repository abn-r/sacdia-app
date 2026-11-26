import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_club.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_clubs_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_club_list_parts.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_load_more_footer.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_scroll.dart';

/// Directory of the clubs of the territory: search by club, church, district
/// or local field, and open the summary of one.
class SupervisionClubsView extends ConsumerWidget {
  const SupervisionClubsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final state = ref.watch(supervisionClubsProvider);
    final notifier = ref.read(supervisionClubsProvider.notifier);
    final searching = state.search.trim().isNotEmpty;

    final Widget content;
    if (state.items.isEmpty && state.error != null) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: isForbiddenFailure(state.error!)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'supervision.clubs.error_title'.tr(),
                message: 'supervision.clubs.error_message'.tr(),
                onRetry: notifier.refresh,
              ),
      );
    } else if (state.items.isEmpty && state.isLoading) {
      content = const SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
        sliver: SliverToBoxAdapter(
          child: SacSkeletonList(
            itemCount: 6,
            leading: false,
            scrollable: false,
          ),
        ),
      );
    } else if (state.items.isEmpty) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: SacEmptyState(
          icon: searching
              ? HugeIcons.strokeRoundedSearch01
              : HugeIcons.strokeRoundedInbox,
          title: (searching
                  ? 'supervision.clubs.empty_search_title'
                  : switch (state.filter) {
                      SupervisionClubActiveFilter.inactive =>
                        'supervision.clubs.empty_inactive_title',
                      _ => 'supervision.clubs.empty_title',
                    })
              .tr(),
          body: (searching
                  ? 'supervision.clubs.empty_search_body'
                  : 'supervision.clubs.empty_body')
              .tr(),
        ),
      );
    } else {
      final groups = groupSupervisionClubsByField(state.items);
      content = SliverPadding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        sliver: SliverList.builder(
          // The groups, and the load-more footer.
          itemCount: groups.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= groups.length) {
              return SupervisionLoadMoreFooter(
                loading: state.isLoadingMore,
                failed: state.error != null,
                errorMessage: 'supervision.clubs.load_more_error'.tr(),
                onLoadMore: notifier.loadMore,
              );
            }
            return SupervisionClubGroupSection(
              group: groups[index],
              // More pages can still add clubs to a field.
              showCount: !state.hasMore,
              onOpen: (club) => context.push(
                RouteNames.supervisionClubDetail('${club.id}'),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'supervision.clubs.title'.tr(),
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: SacAccent.of(context).color,
            edgeOffset: SacTopBar.frostedInset(context),
            onRefresh: notifier.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: SacTopBar.paddingBelowBar(
                    context,
                    const EdgeInsets.only(top: 12),
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: kSupervisionMaxContentWidth,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SacTextField(
                            hint: 'supervision.clubs.search_hint'.tr(),
                            prefixIcon: HugeIcons.strokeRoundedSearch01,
                            textInputAction: TextInputAction.search,
                            autocorrect: false,
                            onChanged: notifier.setSearch,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _ActiveFilter(
                      selected: state.filter,
                      // The server counts only the list on screen: the
                      // other chips stay without a number.
                      selectedCount: state.isLoading ||
                              (state.items.isEmpty && state.error != null)
                          ? null
                          : state.total,
                      onSelected: notifier.setFilter,
                    ),
                  ),
                ),
                // Centered column on a tablet.
                SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final side = (constraints.crossAxisExtent -
                            kSupervisionMaxContentWidth) /
                        2;
                    return SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: side > 0 ? side : 0,
                      ),
                      sliver: content,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilter extends StatelessWidget {
  const _ActiveFilter({
    required this.selected,
    required this.selectedCount,
    required this.onSelected,
  });

  final SupervisionClubActiveFilter selected;
  final int? selectedCount;
  final ValueChanged<SupervisionClubActiveFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = [
      (SupervisionClubActiveFilter.all, 'supervision.clubs.filter_all'),
      (SupervisionClubActiveFilter.active, 'supervision.clubs.filter_active'),
      (
        SupervisionClubActiveFilter.inactive,
        'supervision.clubs.filter_inactive',
      ),
    ];
    return SizedBox(
      height: SacFilterChip.barHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, labelKey) = options[index];
          return Center(
            child: SacFilterChip(
              label: labelKey.tr(),
              selected: filter == selected,
              count: filter == selected ? selectedCount : null,
              onTap: () => onSelected(filter),
            ),
          );
        },
      ),
    );
  }
}
