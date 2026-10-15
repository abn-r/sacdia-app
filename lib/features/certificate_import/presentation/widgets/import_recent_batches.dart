import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/certificate_import_batch_list.dart';
import '../providers/certificate_import_providers.dart';

/// Where a batch status leads and how it reads on the entry screen.
enum ImportBatchStage { draft, inReview, corrections, partial, approved }

/// Maps the API batch status to a [ImportBatchStage]. Unknown values read as
/// "in review": the status screen can always open them.
ImportBatchStage importBatchStageOf(String status) {
  switch (status.toUpperCase()) {
    case 'DRAFT':
    case 'READY_TO_SUBMIT':
      return ImportBatchStage.draft;
    case 'REJECTED':
    case 'NEEDS_CORRECTION':
      return ImportBatchStage.corrections;
    case 'PARTIALLY_APPROVED':
      return ImportBatchStage.partial;
    case 'APPROVED':
      return ImportBatchStage.approved;
    default:
      return ImportBatchStage.inReview;
  }
}

/// Recent batches of the member, so one that needs a correction (or was left
/// as a draft) can be opened again from the entry screen.
///
/// Batches that need a correction go first. Approved ones are left out: there
/// is nothing left to do with them. While loading, on error or with nothing to
/// show the section takes no space, so it never gets in the way of uploading.
class ImportRecentBatches extends ConsumerWidget {
  const ImportRecentBatches({super.key});

  /// Page asked from the API, and how many rows are listed.
  static const _page = (page: 1, limit: 10);
  static const maxShown = 5;

  /// Corrections first, then the API order (most recently modified first).
  static List<CertificateImportBatchSummary> visible(
    List<CertificateImportBatchSummary> batches,
  ) {
    final open = batches
        .where((b) => importBatchStageOf(b.status) != ImportBatchStage.approved)
        .toList();
    final corrections = open
        .where(
            (b) => importBatchStageOf(b.status) == ImportBatchStage.corrections)
        .toList();
    final rest = open.where((b) => !corrections.contains(b));
    return [...corrections, ...rest].take(maxShown).toList(growable: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(certificateImportBatchListProvider(_page));
    final shown = visible(batches.valueOrNull?.items ?? const []);
    if (shown.isEmpty) return const SizedBox.shrink();

    final c = context.sac;
    return Column(
      key: const ValueKey('import-recent-batches'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text(
            'certificate_import.recent.title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 10),
        for (final batch in shown) ...[
          _RecentBatchTile(
            batch: batch,
            onTap: () => _open(context, ref, batch),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    CertificateImportBatchSummary batch,
  ) async {
    // A draft goes back to its rows; the rest to the status of the send.
    final path = importBatchStageOf(batch.status) == ImportBatchStage.draft
        ? RouteNames.certificateImportReviewPath(batch.id)
        : RouteNames.certificateImportStatusPath(batch.id);
    await context.push<void>(path);
    // Back here the batch may have changed (corrected, sent, deleted).
    ref.invalidate(certificateImportBatchListProvider);
  }
}

class _RecentBatchTile extends StatelessWidget {
  const _RecentBatchTile({required this.batch, required this.onTap});

  final CertificateImportBatchSummary batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final stage = importBatchStageOf(batch.status);
    final date = batch.modifiedAt ?? batch.createdAt;
    final details = [
      if (date != null) DateFormat('dd/MM/yyyy').format(date.toLocal()),
      'certificate_import.recent.items'
          .tr(namedArgs: {'count': '${batch.itemCount}'}),
    ].join(' · ');
    return SacCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SacBadge(
                    label: 'certificate_import.recent.${_slug(stage)}'.tr(),
                    variant: _variant(stage),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  details,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            color: c.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }

  static String _slug(ImportBatchStage stage) => switch (stage) {
        ImportBatchStage.draft => 'draft',
        ImportBatchStage.inReview => 'in_review',
        ImportBatchStage.corrections => 'corrections',
        ImportBatchStage.partial => 'partial',
        ImportBatchStage.approved => 'approved',
      };

  static SacBadgeVariant _variant(ImportBatchStage stage) => switch (stage) {
        ImportBatchStage.draft => SacBadgeVariant.neutral,
        ImportBatchStage.inReview => SacBadgeVariant.accent,
        ImportBatchStage.corrections => SacBadgeVariant.error,
        ImportBatchStage.partial => SacBadgeVariant.secondary,
        ImportBatchStage.approved => SacBadgeVariant.primary,
      };
}
