import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/approval_action_buttons.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_enrollment.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_enrollments_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_card_header.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_decision_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_load_more_footer.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';

const double _kMaxContentWidth = 640;

/// Server limits of a rejection reason.
const int _kReasonMinLength = 5;
const int _kReasonMaxLength = 500;

/// Club enrollments of the territory waiting for validation, oldest first,
/// with the decided ones one filter away.
///
/// A card opens the whole enrollment in a sheet; approving or rejecting
/// happens there and only for an actor holding `club_enrollments.validate`.
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
                    const EdgeInsets.only(top: 8),
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _StatusFilter(
                      selected: state.filter,
                      counts: state.counts,
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

// ── Status filter ───────────────────────────────────────────────────────────

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final SupervisionEnrollmentStatus selected;
  final SupervisionEnrollmentCounts? counts;
  final ValueChanged<SupervisionEnrollmentStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        SupervisionEnrollmentStatus.pendingValidation,
        'supervision.enrollments.filter_pending',
        counts?.pending,
      ),
      (
        SupervisionEnrollmentStatus.active,
        'supervision.enrollments.filter_approved',
        counts?.approved,
      ),
      (
        SupervisionEnrollmentStatus.rejected,
        'supervision.enrollments.filter_rejected',
        counts?.rejected,
      ),
    ];
    return SizedBox(
      height: SacFilterChip.barHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (status, labelKey, count) = options[index];
          return Center(
            child: SacFilterChip(
              label: labelKey.tr(),
              selected: status == selected,
              count: count,
              onTap: () => onSelected(status),
            ),
          );
        },
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
    final c = context.sac;
    final items = state.items;
    final pending =
        state.filter == SupervisionEnrollmentStatus.pendingValidation;
    final header = pending ? 1 : 0;
    final footer = state.hasMore ? 1 : 0;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      sliver: SliverList.builder(
        itemCount: header + items.length + footer,
        itemBuilder: (context, index) {
          if (index < header) {
            return Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'supervision.enrollments.oldest_first'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: c.textSecondary),
              ),
            );
          }
          final itemIndex = index - header;
          if (itemIndex >= items.length) {
            return SupervisionLoadMoreFooter(
              loading: state.isLoadingMore,
              failed: state.error != null,
              errorMessage: 'supervision.enrollments.load_more_error'.tr(),
              onLoadMore: onLoadMore,
            );
          }
          final enrollment = items[itemIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EnrollmentCard(
              enrollment: enrollment,
              onTap: () => _showEnrollmentSheet(context, enrollment),
            ),
          );
        },
      ),
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({required this.enrollment, required this.onTap});

  final SupervisionEnrollment enrollment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final decided =
        enrollment.status != SupervisionEnrollmentStatus.pendingValidation;
    final when = decided
        ? enrollment.reviewedAt
        : (enrollment.submittedAt ?? enrollment.createdAt);
    final outcome = _outcomeLine(enrollment);

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: SacCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SupervisionCardHeader(title: enrollment.clubName, when: when),
              const SizedBox(height: 2),
              Text(
                _placeLine(enrollment),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  height: 1.3,
                  color: c.textSecondary,
                ),
              ),
              if (outcome != null) ...[
                const SizedBox(height: 8),
                Text(
                  outcome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    height: 1.3,
                    color: enrollment.status ==
                            SupervisionEnrollmentStatus.rejected
                        ? c.error
                        : c.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Conquistadores · Asociación Norte", skipping whatever the server omitted.
String _placeLine(SupervisionEnrollment enrollment) => [
      enrollment.clubTypeName,
      enrollment.localFieldName,
    ].where((part) => part.trim().isNotEmpty).join(' · ');

/// Who decided, for the cards of the approved and rejected filters.
String? _outcomeLine(SupervisionEnrollment enrollment) {
  final reviewer = enrollment.reviewedBy?.name;
  switch (enrollment.status) {
    case SupervisionEnrollmentStatus.active:
      return reviewer == null
          ? 'supervision.enrollments.approved'.tr()
          : 'supervision.enrollments.approved_by'.tr(args: [reviewer]);
    case SupervisionEnrollmentStatus.rejected:
      final reason = enrollment.decisionReason?.trim();
      if (reason != null && reason.isNotEmpty) return reason;
      return reviewer == null
          ? 'supervision.enrollments.rejected'.tr()
          : 'supervision.enrollments.rejected_by'.tr(args: [reviewer]);
    case SupervisionEnrollmentStatus.pendingValidation:
    case SupervisionEnrollmentStatus.unknown:
      return null;
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

// ── Enrollment sheet ────────────────────────────────────────────────────────

Future<void> _showEnrollmentSheet(
  BuildContext context,
  SupervisionEnrollment enrollment,
) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EnrollmentSheet(enrollment: enrollment),
  );
}

class _EnrollmentSheet extends ConsumerStatefulWidget {
  const _EnrollmentSheet({required this.enrollment});

  final SupervisionEnrollment enrollment;

  @override
  ConsumerState<_EnrollmentSheet> createState() => _EnrollmentSheetState();
}

class _EnrollmentSheetState extends ConsumerState<_EnrollmentSheet> {
  bool _busy = false;
  String? _error;

  SupervisionEnrollment get _enrollment => widget.enrollment;

  Future<void> _approve() async {
    final confirmed = await SacDialog.show(
      context,
      title: 'supervision.enrollments.approve_title'.tr(),
      content: 'supervision.enrollments.approve_message'
          .tr(args: [_enrollment.clubName]),
      confirmLabel: 'coordinator.actions.approve'.tr(),
      cancelLabel: 'common.cancel'.tr(),
      confirmIsSuccess: true,
    );
    if (confirmed != true || !mounted) return;
    await _decide(
      () => ref
          .read(supervisionEnrollmentsProvider.notifier)
          .approve(_enrollment.id),
      'supervision.enrollments.approved_toast',
    );
  }

  Future<void> _reject() async {
    final reason = await showSupervisionDecisionSheet(
      context: context,
      title: 'supervision.enrollments.reject_title'.tr(),
      message: 'supervision.enrollments.reject_message'.tr(),
      fieldLabel: 'supervision.enrollments.reason_label'.tr(),
      fieldHint: 'supervision.enrollments.reason_hint'.tr(),
      confirmLabel: 'coordinator.actions.reject'.tr(),
      minLength: _kReasonMinLength,
      maxLength: _kReasonMaxLength,
    );
    if (reason == null || !mounted) return;
    await _decide(
      () => ref
          .read(supervisionEnrollmentsProvider.notifier)
          .reject(_enrollment.id, reason),
      'supervision.enrollments.rejected_toast',
    );
  }

  Future<void> _decide(
    Future<String?> Function() action,
    String successKey,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await action();
    if (!mounted) return;
    if (failure == null) {
      SacSnackBar.show(context, successKey.tr(), isSuccess: true);
      Navigator.of(context).pop();
      return;
    }
    final code = ref.read(supervisionEnrollmentsProvider).lastActionErrorCode;
    // Someone else already decided it: nothing left to do in this sheet.
    if (code == 'CE_ENROLLMENT_NOT_PENDING' ||
        code == 'CE_ENROLLMENT_NOT_FOUND') {
      SacSnackBar.show(
        context,
        'supervision.enrollments.error_not_pending'.tr(),
        isError: true,
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = code == 'CE_SELF_REVIEW'
          ? 'supervision.enrollments.error_self_review'.tr()
          : supervisionErrorMessage(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final canDecide = hasCapability(user, 'club_enrollments.validate') &&
        _enrollment.status == SupervisionEnrollmentStatus.pendingValidation;
    final subtitle = [
      _placeLine(_enrollment),
      _enrollment.yearName,
    ].where((part) => part.trim().isNotEmpty).join(' · ');

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(title: _enrollment.clubName, subtitle: subtitle),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: _EnrollmentFacts(enrollment: _enrollment),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    height: 1.35,
                    color: c.error,
                  ),
                ),
              ),
            ),
          if (canDecide)
            ApprovalActionBar(
              isLoading: _busy,
              onApprove: _approve,
              onReject: _reject,
            )
          else
            const SafeArea(top: false, child: SizedBox(height: 4)),
        ],
      ),
    );
  }
}

/// Everything the club declared, in three groups; a row exists only when the
/// server sent its value.
class _EnrollmentFacts extends StatelessWidget {
  const _EnrollmentFacts({required this.enrollment});

  final SupervisionEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    String date(DateTime when) => intl.DateFormat.yMMMd(locale).format(when);
    SacValueRow row(String key, String value) => SacValueRow(
          label: 'supervision.enrollments.$key'.tr(),
          value: value,
        );

    final board = enrollment.board;
    // Full translation keys: these are labels of the board, not role checks.
    SacValueRow seat(String labelKey, SupervisionPersonRef person) =>
        SacValueRow(label: labelKey.tr(), value: person.name);
    final boardRows = [
      if (board.director != null)
        seat('supervision.enrollments.director', board.director!),
      for (final deputy in board.deputies)
        seat('supervision.enrollments.deputy', deputy),
      if (board.secretary != null)
        seat('supervision.enrollments.secretary', board.secretary!),
      if (board.treasurer != null)
        seat('supervision.enrollments.treasurer', board.treasurer!),
      if (board.secretaryTreasurer != null)
        seat(
          'supervision.enrollments.secretary_treasurer',
          board.secretaryTreasurer!,
        ),
    ];

    final operationRows = [
      if (_hasText(enrollment.meetingDays))
        row('meeting_days', enrollment.meetingDays!),
      if (_hasText(enrollment.address)) row('address', enrollment.address!),
      if (enrollment.soulsTarget != null)
        row('souls_target', '${enrollment.soulsTarget}'),
      row(
        'fee',
        enrollment.hasFee && enrollment.feeAmount != null
            ? intl.NumberFormat('#,##0.##', locale).format(enrollment.feeAmount)
            : 'supervision.enrollments.fee_none'.tr(),
      ),
    ];

    final requestRows = [
      if (enrollment.submittedBy != null)
        row('submitted_by', enrollment.submittedBy!.name),
      if (enrollment.submittedAt != null)
        row('submitted_at', date(enrollment.submittedAt!)),
      if (enrollment.reviewedBy != null)
        row('reviewed_by', enrollment.reviewedBy!.name),
      if (enrollment.reviewedAt != null)
        row('reviewed_at', date(enrollment.reviewedAt!)),
      if (_hasText(enrollment.decisionReason))
        row('decision_reason', enrollment.decisionReason!),
    ];

    Widget group(String key, List<Widget> rows) => SacGroupedSection(
          label: 'supervision.enrollments.$key'.tr(),
          dividerIndent: 16,
          // A count of rows says nothing here.
          action: const SizedBox.shrink(),
          children: rows,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (boardRows.isNotEmpty) group('board_title', boardRows),
        group('operation_title', operationRows),
        if (requestRows.isNotEmpty) group('request_title', requestRows),
      ],
    );
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
