import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/evidence_review_item.dart';
import '../providers/coordinator_providers.dart';
import '../widgets/evidence_file_gallery.dart';
import '../widgets/approval_action_buttons.dart';

/// Detalle de una evidencia para revisión.
///
/// Muestra información del miembro, galería de archivos, historial de
/// validaciones y botones de aprobación/rechazo.
class EvidenceReviewDetailView extends ConsumerWidget {
  final EvidenceReviewType type;
  final String id;

  const EvidenceReviewDetailView({
    super.key,
    required this.type,
    required this.id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (type: type, id: id);
    final detailAsync = ref.watch(evidenceDetailProvider(key));
    final actionState = ref.watch(evidenceReviewNotifierProvider(key));
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(type.displayLabel),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(evidenceDetailProvider(key)),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 22,
            ),
            tooltip: 'coordinator.evidence_review.detail.refresh_tooltip'.tr(),
          ),
        ],
      ),
      body: detailAsync.when(
        data: (item) => _buildContent(context, ref, item, actionState, hPad, c),
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => _buildError(context, ref, error, key),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    EvidenceReviewItem item,
    EvidenceActionState actionState,
    double hPad,
    SacColors c,
  ) {
    final key = (type: type, id: id);

    return Column(
      children: [
        // ── Scrollable content ─────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Member header ────────────────────────────────────────
                _MemberHeader(item: item, c: c),
                const SizedBox(height: 20),

                // ── Files ────────────────────────────────────────────────
                _Section(
                  title: 'coordinator.evidence_review.detail.section_files'.tr(),
                  icon: HugeIcons.strokeRoundedAttachment01,
                  child: EvidenceFileGallery(files: item.files),
                ),
                const SizedBox(height: 20),

                // ── History ──────────────────────────────────────────────
                if (item.history.isNotEmpty)
                  _Section(
                    title: 'coordinator.evidence_review.detail.section_history'.tr(),
                    icon: HugeIcons.strokeRoundedClock01,
                    child: _HistoryTimeline(history: item.history, c: c),
                  ),
              ],
            ),
          ),
        ),

        // ── Bottom action bar ──────────────────────────────────────────────
        if (item.status == EvidenceReviewStatus.pending)
          Container(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: ApprovalActionBar(
              isLoading: actionState.isLoading,
              onApprove: () => _handleApprove(context, ref, item, key),
              onReject: () => _handleReject(context, ref, item, key),
            ),
          ),
      ],
    );
  }

  Future<void> _handleApprove(
    BuildContext context,
    WidgetRef ref,
    EvidenceReviewItem item,
    EvidenceDetailKey key,
  ) async {
    final comment = await showApproveDialog(
      context: context,
      title: 'coordinator.evidence_review.detail.approve_title'.tr(),
      confirmMessage: 'coordinator.evidence_review.detail.approve_msg'
          .tr(namedArgs: {'name': item.memberName}),
    );

    if (!context.mounted) return;

    final notifier = ref.read(evidenceReviewNotifierProvider(key).notifier);
    final ok = await notifier.approve(comment: comment);

    if (!context.mounted) return;
    showActionSnackbar(
      context,
      message: ok
          ? 'coordinator.evidence_review.detail.approved_ok'.tr()
          : 'coordinator.evidence_review.detail.error_approve'.tr(),
      success: ok,
    );
    if (ok && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _handleReject(
    BuildContext context,
    WidgetRef ref,
    EvidenceReviewItem item,
    EvidenceDetailKey key,
  ) async {
    final reason = await showRejectDialog(
      context: context,
      title: 'coordinator.evidence_review.detail.reject_title'.tr(),
      confirmMessage: 'coordinator.evidence_review.detail.reject_msg'
          .tr(namedArgs: {'name': item.memberName}),
    );

    if (reason == null || !context.mounted) return;

    final notifier = ref.read(evidenceReviewNotifierProvider(key).notifier);
    final ok = await notifier.reject(rejectionReason: reason);

    if (!context.mounted) return;
    showActionSnackbar(
      context,
      message: ok
          ? 'coordinator.evidence_review.detail.rejected_ok'.tr()
          : 'coordinator.evidence_review.detail.error_reject'.tr(),
      success: ok,
    );
    if (ok && context.mounted) Navigator.of(context).pop();
  }

  Widget _buildError(
    BuildContext context,
    WidgetRef ref,
    Object error,
    EvidenceDetailKey key,
  ) {
    final c = context.sac;
    final msg = error.toString().replaceFirst('Exception: ', '');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'coordinator.evidence_review.detail.error_load'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'coordinator.evidence_review.detail.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: () => ref.invalidate(evidenceDetailProvider(key)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Member header ─────────────────────────────────────────────────────────────

class _MemberHeader extends StatelessWidget {
  final EvidenceReviewItem item;
  final SacColors c;

  const _MemberHeader({required this.item, required this.c});

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(item.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          _buildAvatar(context),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.memberName,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                      ),
                    ),
                    _StatusBadge(status: item.status),
                  ],
                ),
                if (item.context != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.type.displayLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.context!,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCalendar01,
                      size: 12,
                      color: c.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'coordinator.evidence_review.detail.submitted_on'.tr(
                        namedArgs: {
                          'date': DateFormat('dd/MM/yyyy')
                              .format(item.submittedAt.toLocal()),
                        },
                      ),
                      style:
                          TextStyle(fontSize: 11, color: c.textTertiary),
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

  Widget _buildAvatar(BuildContext context) {
    final initials = item.memberName.isNotEmpty
        ? item.memberName
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';
    final theme = Theme.of(context);
    final fallback = Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 48,
        height: 48,
        child: (item.memberPhotoUrl != null && item.memberPhotoUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: item.memberPhotoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 96,
                memCacheHeight: 96,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }

  Color _typeColor(EvidenceReviewType type) {
    switch (type) {
      case EvidenceReviewType.folder:
        return AppColors.accent;
      case EvidenceReviewType.classType:
        return AppColors.info;
      case EvidenceReviewType.honor:
        return AppColors.secondary;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final EvidenceReviewStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (labelKey, color) = switch (status) {
      EvidenceReviewStatus.pending => (
          'coordinator.status.pending',
          AppColors.accent
        ),
      EvidenceReviewStatus.approved => (
          'coordinator.status.approved',
          AppColors.secondary
        ),
      EvidenceReviewStatus.rejected => (
          'coordinator.status.rejected',
          AppColors.error
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        labelKey.tr(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<List<dynamic>> icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HugeIcon(
              icon: icon,
              size: 16,
              color: c.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// ── History timeline ──────────────────────────────────────────────────────────

class _HistoryTimeline extends StatelessWidget {
  final List<EvidenceHistoryEntry> history;
  final SacColors c;

  const _HistoryTimeline({required this.history, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: history.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isLast = index == history.length - 1;
        final actionColor = _actionColor(item.action);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline column
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: actionColor,
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
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.action,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: actionColor,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yy HH:mm')
                                .format(item.createdAt.toLocal()),
                            style: TextStyle(
                              fontSize: 10,
                              color: c.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      if (item.actorName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.actorName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                      if (item.comment != null &&
                          item.comment!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '"${item.comment}"',
                            style: TextStyle(
                              fontSize: 11,
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
      }).toList(),
    );
  }

  Color _actionColor(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('approved') || lower.contains('aprobad')) {
      return AppColors.secondary;
    }
    if (lower.contains('rejected') || lower.contains('rechazad')) {
      return AppColors.error;
    }
    return AppColors.info;
  }
}
