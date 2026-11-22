import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

import '../../domain/entities/certificate_import_batch_list.dart';
import '../providers/certificate_import_providers.dart';
import '../utils/import_batch_state.dart';
import '../utils/import_formatters.dart';

export '../utils/import_batch_state.dart'
    show ImportBatchStage, importBatchStageOf, importSummaryStageOf;

/// Recent batches of the member as rows under "Tus envíos", so one that needs
/// a correction (or was left as a draft) can be opened again from the entry
/// screen.
///
/// Batches that need a correction go first. Approved ones are left out: there
/// is nothing left to do with them. While loading, on error or with nothing to
/// show the section takes no space, so it never gets in the way of uploading.
class ImportRecentBatches extends ConsumerWidget {
  const ImportRecentBatches({super.key});

  /// Page asked from the API, and how many rows are listed.
  static const page = (page: 1, limit: 10);
  static const maxShown = 5;

  /// Corrections first, then the API order (most recently modified first).
  static List<CertificateImportBatchSummary> visible(
    List<CertificateImportBatchSummary> batches,
  ) {
    final open = batches
        .where((b) => importSummaryStageOf(b) != ImportBatchStage.approved)
        .toList();
    final corrections = open
        .where((b) => importSummaryStageOf(b) == ImportBatchStage.corrections)
        .toList();
    final rest = open.where((b) => !corrections.contains(b));
    return [...corrections, ...rest].take(maxShown).toList(growable: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(certificateImportBatchListProvider(page));
    final shown = visible(batches.value?.items ?? const []);
    if (shown.isEmpty) return const SizedBox.shrink();

    return SacGroupedSection(
      key: const ValueKey('import-recent-batches'),
      label: 'certificate_import.recent.title'.tr(),
      children: [
        for (final batch in shown)
          _RecentBatchRow(
            key: ValueKey('recent-${batch.id}'),
            batch: batch,
            onTap: () => _open(context, ref, batch),
          ),
      ],
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    CertificateImportBatchSummary batch,
  ) async {
    // A draft goes back to its rows; the rest to the status of the send.
    final path = importSummaryStageOf(batch) == ImportBatchStage.draft
        ? RouteNames.certificateImportReviewPath(batch.id)
        : RouteNames.certificateImportStatusPath(batch.id);
    await context.push<void>(path);
    // Back here the batch may have changed (corrected, sent, deleted).
    ref.invalidate(certificateImportBatchListProvider);
  }
}

class _RecentBatchRow extends StatelessWidget {
  const _RecentBatchRow({super.key, required this.batch, required this.onTap});

  final CertificateImportBatchSummary batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stage = importSummaryStageOf(batch);
    final date = batch.modifiedAt ?? batch.createdAt;
    final rows = (batch.itemCount == 1
            ? 'certificate_import.recent.rows_one'
            : 'certificate_import.recent.rows_other')
        .tr(namedArgs: {'count': '${batch.itemCount}'});
    final needsFix = stage == ImportBatchStage.corrections;
    final label = switch (stage) {
      ImportBatchStage.corrections => batch.rejectedCount == 0
          ? 'certificate_import.recent.corrections_unknown'.tr()
          : (batch.rejectedCount == 1
                  ? 'certificate_import.recent.corrections_one'
                  : 'certificate_import.recent.corrections_other')
              .tr(namedArgs: {'count': '${batch.rejectedCount}'}),
      ImportBatchStage.draft => 'certificate_import.recent.draft'.tr(),
      ImportBatchStage.partial => 'certificate_import.recent.partial'.tr(),
      _ => 'certificate_import.recent.in_review'.tr(),
    };
    return SacStatusRow(
      style: switch (stage) {
        ImportBatchStage.corrections =>
          SacStatusStyle.of(context, SacStatusKind.rejected, label: label),
        ImportBatchStage.draft =>
          SacStatusStyle.of(context, SacStatusKind.pending, label: label),
        ImportBatchStage.partial => SacStatusStyle.of(
            context,
            SacStatusKind.review,
            label: label,
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          ),
        _ => SacStatusStyle.of(context, SacStatusKind.review, label: label),
      },
      title: date == null
          ? 'certificate_import.status.title'.tr()
          : 'certificate_import.recent.batch_title'
              .tr(namedArgs: {'date': importShortDate(date.toLocal())}),
      detail: needsFix ? label : '$label · $rows',
      detailIsError: needsFix,
      onTap: onTap,
    );
  }
}
