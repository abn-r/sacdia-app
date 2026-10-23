import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/instructor_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/approval_action_buttons.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/coordinator_bone.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/evidence_file_gallery.dart';

/// Review screen of one evidence.
///
/// Member, attached files, history and, while the evidence is pending, the
/// sticky reject / approve bar. It is a full-screen route outside the shell.
/// Approving or rejecting invalidates the pending list, this detail and the
/// SLA counters (see [EvidenceReviewNotifier]) and then pops back.
class EvidenceReviewDetailView extends ConsumerWidget {
  const EvidenceReviewDetailView({
    super.key,
    required this.type,
    required this.id,
  });

  final EvidenceReviewType type;
  final String id;

  EvidenceDetailKey get _key => (type: type, id: id);

  /// Back from a full-screen route: pop, or, when opened without a stack
  /// (deep link), go to the review queue.
  void _back(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else if (GoRouter.maybeOf(context) != null) {
      context.go(RouteNames.coordinatorEvidenceReview);
    }
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(evidenceDetailProvider(_key));
    try {
      await ref.read(evidenceDetailProvider(_key).future);
    } catch (_) {
      // The error state renders the failure.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final detailAsync = ref.watch(evidenceDetailProvider(_key));
    final actionState = ref.watch(evidenceReviewNotifierProvider(_key));

    // Only a successfully loaded, still pending evidence can be reviewed. The
    // bar lives in `bottomNavigationBar` so floating snack bars (a failed
    // action) appear above it instead of covering the buttons.
    final pending = detailAsync.hasError ? null : detailAsync.valueOrNull;
    final showActions =
        pending != null && pending.status == EvidenceReviewStatus.pending;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'coordinator.evidence_review.detail.title'.tr(),
        frosted: true,
        onBack: () => _back(context),
      ),
      bottomNavigationBar: showActions
          ? ApprovalActionBar(
              isLoading: actionState.isLoading,
              onApprove: () => _handleApprove(context, ref, pending),
              onReject: () => _handleReject(context, ref, pending),
            )
          : null,
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => detailAsync.when(
            skipLoadingOnReload: detailAsync.hasValue,
            loading: () => const _DetailScroll(
              onRefresh: null,
              children: [_DetailSkeleton()],
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
                        'coordinator.evidence_review.detail.error_title'.tr(),
                    message:
                        'coordinator.evidence_review.detail.error_message'.tr(),
                    onRetry: () => ref.invalidate(evidenceDetailProvider(_key)),
                    padding: SacTopBar.paddingBelowBar(
                      context,
                      const EdgeInsets.all(32),
                    ),
                  ),
            data: (item) => _DetailScroll(
              onRefresh: () => _refresh(ref),
              children: [
                _MemberHeader(item: item),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'coordinator.evidence_review.detail.section_files'
                      .tr(namedArgs: {'count': '${item.files.length}'}),
                ),
                EvidenceFileGallery(files: item.files),
                if (item.history.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'coordinator.evidence_review.detail.section_history'
                        .tr(),
                  ),
                  _HistoryCard(history: item.history),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleApprove(
    BuildContext context,
    WidgetRef ref,
    EvidenceReviewItem item,
  ) async {
    final comment = await showApproveDialog(
      context: context,
      title: 'coordinator.evidence_review.detail.approve_title'.tr(),
      confirmMessage: 'coordinator.evidence_review.detail.approve_msg'
          .tr(namedArgs: {'name': item.displayMemberName}),
    );
    // Null means the coordinator cancelled: nothing is sent.
    if (comment == null || !context.mounted) return;

    final ok = await ref
        .read(evidenceReviewNotifierProvider(_key).notifier)
        .approve(comment: comment.isEmpty ? null : comment);
    if (!context.mounted) return;

    if (ok) HapticFeedback.lightImpact();
    SacSnackBar.show(
      context,
      ok
          ? 'coordinator.evidence_review.detail.approved_ok'.tr()
          : 'coordinator.evidence_review.detail.error_approve'.tr(),
      isError: !ok,
    );
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _handleReject(
    BuildContext context,
    WidgetRef ref,
    EvidenceReviewItem item,
  ) async {
    final reason = await showRejectSheet(
      context: context,
      title: 'coordinator.evidence_review.detail.reject_title'.tr(),
      message: 'coordinator.evidence_review.detail.reject_msg'
          .tr(namedArgs: {'name': item.displayMemberName}),
    );
    if (reason == null || !context.mounted) return;

    final ok = await ref
        .read(evidenceReviewNotifierProvider(_key).notifier)
        .reject(rejectionReason: reason);
    if (!context.mounted) return;

    if (ok) HapticFeedback.mediumImpact();
    SacSnackBar.show(
      context,
      ok
          ? 'coordinator.evidence_review.detail.rejected_ok'.tr()
          : 'coordinator.evidence_review.detail.error_reject'.tr(),
      isError: !ok,
    );
    if (ok) Navigator.of(context).pop();
  }
}

// ── Scroll scaffold ───────────────────────────────────────────────────────────

class _DetailScroll extends StatelessWidget {
  const _DetailScroll({required this.onRefresh, required this.children});

  final Future<void> Function()? onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: SacTopBar.paddingBelowBar(
            context,
            EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
          ),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
    if (onRefresh == null) return scroll;
    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: onRefresh!,
      child: scroll,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.sac.textSecondary,
              ),
        ),
      ),
    );
  }
}

// ── Member header ─────────────────────────────────────────────────────────────

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.item});

  final EvidenceReviewItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final deleted = item.memberIsDeleted;
    final where = [
      item.context?.trim(),
      item.clubSectionLabel?.trim(),
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return SacCard(
      animate: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InstructorAvatar(
            name: deleted ? '?' : item.memberName,
            photoUrl: deleted ? null : item.memberPhotoUrl,
            size: 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayMemberName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: deleted ? c.textTertiary : c.text,
                    fontStyle: deleted ? FontStyle.italic : null,
                  ),
                ),
                if (where.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    where,
                    style:
                        textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StatusBadge(status: item.status),
                    SacBadge(
                      variant: SacBadgeVariant.neutral,
                      label: item.type.displayLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCalendar01,
                      size: 14,
                      color: c.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'coordinator.evidence_review.detail.submitted_on'.tr(
                          namedArgs: {
                            'date': DateFormat('dd/MM/yyyy')
                                .format(item.submittedAt.toLocal()),
                          },
                        ),
                        style: textTheme.labelMedium
                            ?.copyWith(color: c.textTertiary),
                      ),
                    ),
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

/// Pending is warning, approved success and rejected error.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final EvidenceReviewStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case EvidenceReviewStatus.pending:
        return SacBadge.warning(label: 'coordinator.status.pending'.tr());
      case EvidenceReviewStatus.approved:
        return SacBadge.success(label: 'coordinator.status.approved'.tr());
      case EvidenceReviewStatus.rejected:
        return SacBadge.error(label: 'coordinator.status.rejected'.tr());
    }
  }
}

// ── History timeline ──────────────────────────────────────────────────────────

/// What a raw history `action` means. The backend sends enum-like strings
/// (`SUBMITTED`, `APPROVED`, `instructor_proposed`...) in either case.
@visibleForTesting
enum EvidenceHistoryKind {
  submitted,
  approved,
  rejected,
  instructorProposed,
  instructorSet,
  other,
}

@visibleForTesting
EvidenceHistoryKind evidenceHistoryKind(String action) {
  final a = action.toLowerCase().trim();
  if (a.contains('reject') || a.contains('rechaz')) {
    return EvidenceHistoryKind.rejected;
  }
  if (a.contains('approv') || a.contains('aprob')) {
    return EvidenceHistoryKind.approved;
  }
  if (a == 'instructor_proposed') return EvidenceHistoryKind.instructorProposed;
  if (a == 'instructor_set') return EvidenceHistoryKind.instructorSet;
  if (a.contains('submit') || a.contains('envi')) {
    return EvidenceHistoryKind.submitted;
  }
  return EvidenceHistoryKind.other;
}

/// Localized label for a history `action`; unknown actions are humanized
/// ("reinvestiture_requested" becomes "Reinvestiture requested").
@visibleForTesting
String evidenceHistoryLabel(String action) {
  const prefix = 'coordinator.evidence_review.history';
  switch (evidenceHistoryKind(action)) {
    case EvidenceHistoryKind.submitted:
      return '$prefix.submitted'.tr();
    case EvidenceHistoryKind.approved:
      return '$prefix.approved'.tr();
    case EvidenceHistoryKind.rejected:
      return '$prefix.rejected'.tr();
    case EvidenceHistoryKind.instructorProposed:
      return '$prefix.instructor_proposed'.tr();
    case EvidenceHistoryKind.instructorSet:
      return '$prefix.instructor_set'.tr();
    case EvidenceHistoryKind.other:
      final text = action.replaceAll('_', ' ').trim().toLowerCase();
      if (text.isEmpty) return action;
      return '${text[0].toUpperCase()}${text.substring(1)}';
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final List<EvidenceHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    return SacCard(
      child: Column(
        children: [
          for (var i = 0; i < history.length; i++)
            _HistoryRow(entry: history[i], isLast: i == history.length - 1),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.isLast});

  final EvidenceHistoryEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final dotColor = switch (evidenceHistoryKind(entry.action)) {
      EvidenceHistoryKind.approved => c.success,
      EvidenceHistoryKind.rejected => c.error,
      _ => c.textTertiary,
    };
    final comment = entry.comment?.trim() ?? '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: c.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          evidenceHistoryLabel(entry.action),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM/yy HH:mm')
                            .format(entry.createdAt.toLocal()),
                        style: textTheme.labelSmall
                            ?.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                  if (entry.actorName != null &&
                      entry.actorName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.actorName!.trim(),
                      style:
                          textTheme.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                  ],
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                      ),
                      child: Text(
                        comment,
                        style: textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

/// Matches the loaded layout: member card, files grid and history card.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SacCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoordinatorBone(width: 56, height: 56, circle: true),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CoordinatorBone(width: 170, height: 16),
                      SizedBox(height: 8),
                      CoordinatorBone(width: 210, height: 12),
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
          ),
          SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: CoordinatorBone(width: 96, height: 14),
          ),
          Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CoordinatorBone(radius: AppTheme.radiusSM),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CoordinatorBone(radius: AppTheme.radiusSM),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CoordinatorBone(radius: AppTheme.radiusSM),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: CoordinatorBone(width: 72, height: 14),
          ),
          SacCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoordinatorBone(width: 140, height: 14),
                SizedBox(height: 8),
                CoordinatorBone(width: 100, height: 12),
                SizedBox(height: 20),
                CoordinatorBone(width: 120, height: 14),
                SizedBox(height: 8),
                CoordinatorBone(width: 90, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
