import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
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
import 'package:sacdia_app/features/supervision/domain/entities/supervision_enrollment.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_enrollments_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_enrollment_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_load_more_footer.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_row_parts.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_segmented_control.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_status_chip.dart';
import 'package:sacdia_app/features/transfers/presentation/widgets/club_type_tile.dart';

const double _kMaxContentWidth = 640;

/// Club enrollments of the territory waiting for validation, oldest first,
/// with the decided ones one segment away.
///
/// One grouped list with the logo of the club type on every row. A row opens
/// the whole enrollment in a sheet; approving or rejecting happens there and
/// only for an actor holding `club_enrollments.validate`.
class SupervisionEnrollmentsView extends ConsumerWidget {
  const SupervisionEnrollmentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final state = ref.watch(supervisionEnrollmentsProvider);
    final notifier = ref.read(supervisionEnrollmentsProvider.notifier);

    final Widget content;
    if (state.items.isEmpty && state.error != null) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: isForbiddenFailure(state.error!)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'supervision.enrollments.error_title'.tr(),
                message: 'supervision.enrollments.error_message'.tr(),
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
        child: _EmptyQueue(filter: state.filter),
      );
    } else {
      content = _EnrollmentsSliver(state: state, onLoadMore: notifier.loadMore);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'supervision.enrollments.title'.tr(),
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
                        SupervisionEnrollmentStatus>(
                      selected: state.filter,
                      onChanged: notifier.setFilter,
                      segments: [
                        SupervisionSegment(
                          value: SupervisionEnrollmentStatus.pendingValidation,
                          label: 'supervision.enrollments.filter_pending'.tr(),
                          count: state.counts?.pending,
                        ),
                        SupervisionSegment(
                          value: SupervisionEnrollmentStatus.active,
                          label: 'supervision.enrollments.filter_approved'.tr(),
                          count: state.counts?.approved,
                        ),
                        SupervisionSegment(
                          value: SupervisionEnrollmentStatus.rejected,
                          label: 'supervision.enrollments.filter_rejected'.tr(),
                          count: state.counts?.rejected,
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

// ── Queue ───────────────────────────────────────────────────────────────────

class _EnrollmentsSliver extends StatelessWidget {
  const _EnrollmentsSliver({required this.state, required this.onLoadMore});

  final SupervisionEnrollmentsState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    final pending =
        state.filter == SupervisionEnrollmentStatus.pendingValidation;

    return SliverPadding(
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
                errorMessage: 'supervision.enrollments.load_more_error'.tr(),
                onLoadMore: onLoadMore,
              ),
            );
          }
          return SacGroupedSection(
            label: (pending
                    ? 'supervision.enrollments.oldest_first'
                    : 'supervision.enrollments.this_year')
                .tr(),
            count: math.max(state.total, items.length),
            children: [
              for (final enrollment in items)
                _EnrollmentRow(
                  key: ValueKey(enrollment.id),
                  enrollment: enrollment,
                  onTap: () =>
                      showSupervisionEnrollmentSheet(context, enrollment),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EnrollmentRow extends StatelessWidget {
  const _EnrollmentRow({
    super.key,
    required this.enrollment,
    required this.onTap,
  });

  final SupervisionEnrollment enrollment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final status = enrollment.status;
    final decided = status == SupervisionEnrollmentStatus.active ||
        status == SupervisionEnrollmentStatus.rejected;
    final place = enrollmentPlaceLine(enrollment);
    final placeText = Text(
      place,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: SacFontSize.bodyMedium,
        height: 1.3,
        color: c.textSecondary,
      ),
    );

    return SacListRow(
      leading: ClubTypeTile(clubTypeName: enrollment.clubTypeName),
      title: enrollment.clubName,
      subtitleWidget: decided
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                placeText,
                const SizedBox(height: 6),
                if (status == SupervisionEnrollmentStatus.active)
                  SupervisionStatusChip(
                    label: 'supervision.enrollments.approved'.tr(),
                    icon: HugeIcons.strokeRoundedTick02,
                    tone: SacTone.success,
                  )
                else
                  SupervisionStatusChip(
                    label: 'supervision.enrollments.rejected'.tr(),
                    icon: HugeIcons.strokeRoundedCancel01,
                    tone: SacTone.error,
                  ),
              ],
            )
          : placeText,
      trailing: SupervisionRowAge(
        when: decided
            ? enrollment.reviewedAt
            : (enrollment.submittedAt ?? enrollment.createdAt),
        absolute: decided,
      ),
      onTap: onTap,
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.filter});

  final SupervisionEnrollmentStatus filter;

  @override
  Widget build(BuildContext context) {
    final (titleKey, bodyKey) = switch (filter) {
      SupervisionEnrollmentStatus.active => (
          'supervision.enrollments.empty_approved_title',
          'supervision.enrollments.empty_decided_body',
        ),
      SupervisionEnrollmentStatus.rejected => (
          'supervision.enrollments.empty_rejected_title',
          'supervision.enrollments.empty_decided_body',
        ),
      _ => (
          'supervision.enrollments.empty_pending_title',
          'supervision.enrollments.empty_pending_body',
        ),
    };
    return SacEmptyState(title: titleKey.tr(), body: bodyKey.tr());
  }
}
