import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_folders_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_card_header.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_folder_labels.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_load_more_footer.dart';

const double _kMaxContentWidth = 640;

/// Annual folders of the territory with sections waiting for an evaluation,
/// with the evaluated ones and the whole list one filter away.
class SupervisionFoldersView extends ConsumerWidget {
  const SupervisionFoldersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final state = ref.watch(supervisionFoldersQueueProvider);
    final notifier = ref.read(supervisionFoldersQueueProvider.notifier);

    final Widget content;
    if (state.items.isEmpty && state.error != null) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: isForbiddenFailure(state.error!)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'supervision.folders.error_title'.tr(),
                message: 'supervision.folders.error_message'.tr(),
                onRetry: notifier.refresh,
              ),
      );
    } else if (state.items.isEmpty && state.isLoading) {
      content = const SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
        sliver: SliverToBoxAdapter(
          child: SacSkeletonList(
            itemCount: 5,
            leading: false,
            scrollable: false,
          ),
        ),
      );
    } else if (state.items.isEmpty) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: SacEmptyState(
          title: switch (state.filter) {
            SupervisionFolderQueueFilter.needsReview =>
              'supervision.folders.empty_review_title',
            SupervisionFolderQueueFilter.evaluated =>
              'supervision.folders.empty_evaluated_title',
            SupervisionFolderQueueFilter.all =>
              'supervision.folders.empty_all_title',
          }
              .tr(),
          body: 'supervision.folders.empty_body'.tr(),
        ),
      );
    } else {
      final items = state.items;
      content = SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        sliver: SliverList.builder(
          itemCount: items.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= items.length) {
              return SupervisionLoadMoreFooter(
                loading: state.isLoadingMore,
                failed: state.error != null,
                errorMessage: 'supervision.folders.load_more_error'.tr(),
                onLoadMore: notifier.loadMore,
              );
            }
            final folder = items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FolderCard(
                folder: folder,
                onTap: () => context.push(
                  RouteNames.supervisionFolderDetail(folder.id),
                ),
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
        title: 'supervision.folders.title'.tr(),
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
              slivers: [
                SliverPadding(
                  padding: SacTopBar.paddingBelowBar(
                    context,
                    const EdgeInsets.only(top: 8),
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _QueueFilter(
                      selected: state.filter,
                      onSelected: notifier.setFilter,
                    ),
                  ),
                ),
                // Centered column on a tablet.
                SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final side =
                        (constraints.crossAxisExtent - _kMaxContentWidth) / 2;
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

class _QueueFilter extends StatelessWidget {
  const _QueueFilter({required this.selected, required this.onSelected});

  final SupervisionFolderQueueFilter selected;
  final ValueChanged<SupervisionFolderQueueFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = [
      (
        SupervisionFolderQueueFilter.needsReview,
        'supervision.folders.filter_review',
      ),
      (
        SupervisionFolderQueueFilter.evaluated,
        'supervision.folders.filter_evaluated',
      ),
      (SupervisionFolderQueueFilter.all, 'supervision.folders.filter_all'),
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
              onTap: () => onSelected(filter),
            ),
          );
        },
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.folder, required this.onTap});

  final SupervisionFolderQueueItem folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final title = folder.displayName.trim().isNotEmpty
        ? folder.displayName
        : folder.clubName;
    final place = [
      folder.clubTypeName,
      folder.localFieldName,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final when = folder.latestSubmittedAt ?? folder.createdAt;
    final waiting = folder.pendingSectionNames;

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: SacCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SupervisionCardHeader(title: title, when: when),
              if (place.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  place,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    height: 1.3,
                    color: c.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // What waits inside, by name; otherwise where the folder stands.
              Text(
                waiting.isNotEmpty
                    ? 'supervision.folders.waiting_sections'
                        .tr(args: [waiting.join(', ')])
                    : folderStatusLabel(folder.folderStatus),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  height: 1.3,
                  color: waiting.isNotEmpty ? c.text : c.textSecondary,
                  fontWeight:
                      waiting.isNotEmpty ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
