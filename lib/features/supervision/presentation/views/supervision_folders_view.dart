import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_folders_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_folder_labels.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_load_more_footer.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_row_parts.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_segmented_control.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_status_chip.dart';
import 'package:sacdia_app/features/transfers/presentation/widgets/club_type_tile.dart';

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
        padding: const EdgeInsets.only(bottom: 32),
        sliver: SliverList.builder(
          itemCount: 1 + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index > 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SupervisionLoadMoreFooter(
                  loading: state.isLoadingMore,
                  failed: state.error != null,
                  errorMessage: 'supervision.folders.load_more_error'.tr(),
                  onLoadMore: notifier.loadMore,
                ),
              );
            }
            return SacGroupedSection(
              label: switch (state.filter) {
                SupervisionFolderQueueFilter.needsReview =>
                  'supervision.folders.oldest_first',
                SupervisionFolderQueueFilter.evaluated =>
                  'supervision.folders.filter_evaluated',
                SupervisionFolderQueueFilter.all =>
                  'supervision.folders.filter_all',
              }
                  .tr(),
              count: math.max(state.total, items.length),
              children: [
                for (final folder in items)
                  _FolderRow(
                    key: ValueKey(folder.id),
                    folder: folder,
                    onTap: () => context.push(
                      RouteNames.supervisionFolderDetail(folder.id),
                    ),
                  ),
              ],
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
                    const EdgeInsets.only(top: 0),
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SupervisionSegmentedControl<
                        SupervisionFolderQueueFilter>(
                      selected: state.filter,
                      onChanged: notifier.setFilter,
                      segments: [
                        for (final (filter, labelKey) in const [
                          (
                            SupervisionFolderQueueFilter.needsReview,
                            'supervision.folders.filter_review',
                          ),
                          (
                            SupervisionFolderQueueFilter.evaluated,
                            'supervision.folders.filter_evaluated',
                          ),
                          (
                            SupervisionFolderQueueFilter.all,
                            'supervision.folders.filter_all',
                          ),
                        ])
                          SupervisionSegment(
                            value: filter,
                            label: labelKey.tr(),
                            // The API counts only the list it returns: the
                            // other segments carry no number.
                            count: filter == state.filter &&
                                    !state.isLoading &&
                                    state.error == null
                                ? state.total
                                : null,
                          ),
                      ],
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

/// A folder of the queue: the logo of its club type, where it belongs, how
/// many sections wait (amber: yours to evaluate; blue: waiting for the Union)
/// and a thin bar with the share of sections already evaluated.
class _FolderRow extends StatelessWidget {
  const _FolderRow({super.key, required this.folder, required this.onTap});

  final SupervisionFolderQueueItem folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final title = folder.displayName.trim().isNotEmpty
        ? folder.displayName
        : folder.clubName;
    // The folder's own name usually carries the section ("ACV · Aventureros
    // · 2026"): it is not said twice.
    final type = folder.clubTypeName.trim();
    final typeInTitle =
        type.isNotEmpty && title.toLowerCase().contains(type.toLowerCase());
    final place = [
      if (!typeInTitle) folder.clubTypeName,
      folder.localFieldName,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final toEvaluate = folder.submittedSections;
    final waitingUnion = folder.preapprovedSections;
    final evaluated = folder.validatedSections +
        folder.preapprovedSections +
        folder.rejectedSections;
    final progress = folder.totalSections > 0
        ? (evaluated / folder.totalSections).clamp(0.0, 1.0)
        : null;

    return SacListRow(
      leading: ClubTypeTile(clubTypeName: folder.clubTypeName),
      title: title,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (place.isNotEmpty)
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
          if (toEvaluate > 0 || waitingUnion > 0) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (toEvaluate > 0)
                  SupervisionStatusChip(
                    label: 'supervision.folders.n_to_evaluate'
                        .tr(args: ['$toEvaluate']),
                    icon: HugeIcons.strokeRoundedInbox,
                    tone: SacTone.warning,
                  ),
                if (waitingUnion > 0)
                  SupervisionStatusChip(
                    label: 'supervision.folders.n_waiting_union'
                        .plural(waitingUnion),
                    icon: HugeIcons.strokeRoundedClock01,
                    tone: SacTone.info,
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 2),
            Text(
              folderStatusLabel(folder.folderStatus),
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                height: 1.3,
                color: c.textSecondary,
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 8),
            Semantics(
              label:
                  '${'supervision.folders.progress'.tr()} ${supervisionPercent(progress * 100)}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  color: c.success,
                  backgroundColor: c.surfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: SupervisionRowAge(
        when: folder.latestSubmittedAt ?? folder.createdAt,
      ),
      onTap: onTap,
    );
  }
}
