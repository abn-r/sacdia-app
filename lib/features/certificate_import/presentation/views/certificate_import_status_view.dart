import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../domain/entities/certificate_import_payloads.dart';
import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/entities/certificate_import_item.dart';
import '../../domain/usecases/resubmit_certificate_import_item.dart';
import '../error/certificate_import_error_mapper.dart';
import '../providers/certificate_import_providers.dart';
import '../widgets/certificate_import_back_button.dart';
import '../utils/import_batch_state.dart';
import '../utils/import_formatters.dart';
import '../widgets/import_item_row.dart';
import '../widgets/certificate_import_item_editor_sheet.dart';
import '../widgets/import_load_error_scaffold.dart';

class CertificateImportStatusRouteView extends ConsumerWidget {
  const CertificateImportStatusRouteView({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchAsync = ref.watch(certificateImportBatchProvider(batchId));
    return batchAsync.when(
      loading: () => const Scaffold(body: Center(child: SacLoading())),
      error: (_, __) => ImportLoadErrorScaffold(
        title: 'certificate_import.status.title'.tr(),
        bodyKey: 'certificate_import.status.load_error',
        fallbackLocation: RouteNames.certificateImportUpload,
        onRetry: () => ref.invalidate(certificateImportBatchProvider(batchId)),
      ),
      data: (batch) => CertificateImportStatusView(
        batch: batch,
        // Pull to see the reviewer's decisions without leaving the screen.
        onRefresh: () async {
          ref.invalidate(certificateImportBatchListProvider);
          ref.invalidate(certificateImportBatchProvider(batchId));
          try {
            await ref.read(certificateImportBatchProvider(batchId).future);
          } catch (_) {
            // The screen shows the error state with its own retry.
          }
        },
        onResubmitItem: (item, previous) async {
          final result =
              await ref.read(resubmitCertificateImportItemProvider).call(
                    ResubmitCertificateImportItemParams(
                      batchId: batch.id,
                      itemId: item.id,
                      payload: CertificateImportItemUpdatePayload.fromItem(
                        item,
                        previous: previous,
                        markAsReady: true,
                      ),
                    ),
                  );
          // The row left the rejected state either way (resent now, or
          // already resent): reload so the card, counters and status match.
          void refresh() {
            ref.invalidate(certificateImportBatchProvider(batch.id));
            ref.invalidate(certificateImportBatchListProvider);
          }

          result.fold(
            (failure) {
              if (CertificateImportErrorMapper.kindOf(failure) ==
                  CertificateImportErrorKind.itemNotRejected) {
                refresh();
              }
              throw failure;
            },
            (_) => refresh(),
          );
        },
      ),
    );
  }
}

class CertificateImportStatusView extends StatelessWidget {
  const CertificateImportStatusView({
    super.key,
    required this.batch,
    this.onResubmitItem,
    this.onRefresh,
  });

  final CertificateImportBatch batch;

  /// Reloads the batch; without it the screen has no pull to refresh.
  final Future<void> Function()? onRefresh;

  /// Sends the corrected [updated] row; [previous] is the rejected one. Throws
  /// the failure when the API refuses, so the editor can show it.
  final Future<void> Function(
    CertificateImportItem updated,
    CertificateImportItem previous,
  )? onResubmitItem;

  /// "Corregir y reenviar": opens the row editor on the rejected [item] and
  /// resubmits what the member fixed. The editor stays open on errors.
  Future<void> _openResubmitEditor(
    BuildContext context,
    CertificateImportItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await showCertificateImportItemEditor(
      context,
      item: item,
      resubmit: true,
      onSave: (updated) async {
        try {
          await onResubmitItem?.call(updated, item);
          SacSnackBar.showMessenger(
            messenger,
            'certificate_import.status.resubmitted'.tr(),
          );
        } catch (error) {
          if (CertificateImportErrorMapper.kindOf(error) !=
              CertificateImportErrorKind.itemNotRejected) {
            rethrow;
          }
          // Nothing left to fix here: say so and let the sheet close.
          SacSnackBar.showMessenger(
            messenger,
            CertificateImportErrorMapper.message(error),
            isError: true,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final state = ImportBatchState.of(batch);
    final groups = state.groups;
    final items = batch.activeItems;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: importBatchTitle(batch),
          leading: const CertificateImportBackButton(
            // Back lands on "Carga por certificado", never on the review that
            // was already sent.
            fallbackLocation: RouteNames.certificateImportUpload,
          ),
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => _MaybeRefresh(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: SacTopBar.paddingBelowBar(
                  context, const EdgeInsets.fromLTRB(0, 8, 0, 28)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StatePanel(batch: batch, state: state),
                ),
                for (final notice in [
                  if (items.any((item) => item.isGuiaMayorBase))
                    'certificate_import.status.gm01_replace',
                  if (items.any((item) => item.isInstitutionalClass))
                    'certificate_import.status.institutional',
                  if (items.any((item) => item.isPendingAdministrativePeriod))
                    'certificate_import.status.period_pending',
                ])
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                    child: Text(
                      notice.tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                          ),
                    ),
                  ),
                if (groups.toFix.isNotEmpty)
                  SacGroupedSection(
                    key: const ValueKey('status-group-fix'),
                    label: 'certificate_import.status.group_fix'.tr(),
                    children: [
                      for (final item in groups.toFix) _fixRow(context, item),
                    ],
                  ),
                if (groups.inReview.isNotEmpty)
                  SacGroupedSection(
                    key: const ValueKey('status-group-review'),
                    label: 'certificate_import.status.group_review'.tr(),
                    children: [
                      for (final item in groups.inReview) _readOnlyRow(item),
                    ],
                  ),
                if (groups.approved.isNotEmpty)
                  SacGroupedSection(
                    key: const ValueKey('status-group-approved'),
                    label: 'certificate_import.status.group_approved'.tr(),
                    children: [
                      for (final item in groups.approved) _readOnlyRow(item),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A row the reviewer sent back: the reason in the error color, tap to
  /// correct and resubmit.
  Widget _fixRow(BuildContext context, CertificateImportItem item) {
    final reason = item.isPendingAdministrativePeriod
        ? 'certificate_import.item.period_pending'.tr()
        : (item.rejectionReason?.trim().isNotEmpty ?? false)
            ? item.rejectionReason!.trim()
            : 'certificate_import.status.fix_no_reason'.tr();
    return ImportItemRow(
      key: ValueKey('status-row-${item.id}'),
      item: item,
      subtitle: reason,
      tone: ImportRowTone.error,
      trailing: Text(
        'certificate_import.status.fix'.tr(),
        style: TextStyle(
          fontSize: SacFontSize.titleSmall,
          fontWeight: FontWeight.w600,
          color: SacAccent.of(context).dark,
        ),
      ),
      onTap: () => _openResubmitEditor(context, item),
    );
  }

  Widget _readOnlyRow(CertificateImportItem item) {
    final resent = item.status == CertificateImportItemStatus.resubmitted;
    final detail = importReviewSubtitle(item).text;
    return ImportItemRow(
      key: ValueKey('status-row-${item.id}'),
      item: item,
      subtitle: resent
          ? [
              'certificate_import.item.resubmitted'.tr(),
              if (detail.isNotEmpty) detail,
            ].join(' · ')
          : detail,
    );
  }
}

/// The state of the whole batch in a panel; tapping it opens every state.
/// Pull to refresh under the frosted bar, only when there is a reload.
class _MaybeRefresh extends StatelessWidget {
  const _MaybeRefresh({required this.onRefresh, required this.child});

  final Future<void> Function()? onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reload = onRefresh;
    if (reload == null) return child;
    return RefreshIndicator(
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: reload,
      child: child,
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.batch, required this.state});

  final CertificateImportBatch batch;
  final ImportBatchState state;

  String _plural(String base, int count) =>
      '$base${count == 1 ? '_one' : '_other'}'.tr(
        namedArgs: {'count': '$count'},
      );

  @override
  Widget build(BuildContext context) {
    final String title;
    final String message;
    final SacStatusStyle style;
    switch (state.kind) {
      case ImportBatchStateKind.corrections:
        title =
            _plural('certificate_import.status.corrections', state.toFixCount);
        message = _plural(
            'certificate_import.status.corrections_msg', state.toFixCount);
        style =
            SacStatusStyle.of(context, SacStatusKind.rejected, label: title);
      case ImportBatchStateKind.approved:
        title = 'certificate_import.status.approved_title'.tr();
        message = 'certificate_import.status.approved_body'.tr();
        style =
            SacStatusStyle.of(context, SacStatusKind.validated, label: title);
      case ImportBatchStateKind.partial:
        title = 'certificate_import.status.partial_title'.tr();
        message = 'certificate_import.status.partial_body'.tr();
        style = SacStatusStyle.of(
          context,
          SacStatusKind.review,
          label: title,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case ImportBatchStateKind.inReview:
        title = 'certificate_import.status.in_review_title'.tr();
        message = 'certificate_import.status.in_review_body'.tr();
        style = SacStatusStyle.of(context, SacStatusKind.review, label: title);
    }
    return SacStatePanel(
      key: const ValueKey('import-batch-state-panel'),
      style: style,
      title: title,
      message: message,
      stepLabel: 'certificate_import.status.see_states'.tr(),
      semanticsHint: 'certificate_import.status.panel_hint'.tr(),
      onTap: () => _showStates(context),
    );
  }

  void _showStates(BuildContext context) {
    final kind = state.kind;
    final fixing = kind == ImportBatchStateKind.corrections;
    final approvedAll = kind == ImportBatchStateKind.approved;
    final sent = batch.submittedAt;
    final sentDate = sent == null ? null : importShortDate(sent.toLocal());

    final SacStateKind review = fixing
        ? SacStateKind.pending
        : approvedAll
            ? SacStateKind.done
            : SacStateKind.current;
    final SacStateKind approved =
        approvedAll ? SacStateKind.current : SacStateKind.pending;

    showSacStatesSheet(
      context,
      title: 'certificate_import.status.sheet_title'.tr(),
      subtitle: importBatchTitle(batch),
      steps: [
        SacStateStep(
          kind: SacStateKind.done,
          title: 'certificate_import.status.state_sent'.tr(),
          detail: sentDate == null
              ? null
              : 'certificate_import.status.sent_on'
                  .tr(namedArgs: {'date': sentDate}),
        ),
        SacStateStep(
          kind: review,
          title: 'certificate_import.status.in_review_title'.tr(),
          detail: switch (review) {
            SacStateKind.current when state.approvedCount > 0 =>
              'certificate_import.status.approved_progress'.tr(namedArgs: {
                'approved': '${state.approvedCount}',
                'total': '${state.total}',
              }),
            SacStateKind.current =>
              'certificate_import.status.in_review_body'.tr(),
            _ => 'certificate_import.status.review_next'.tr(),
          },
        ),
        SacStateStep(
          kind: approved,
          title: 'certificate_import.status.approved_title'.tr(),
          detail: 'certificate_import.status.approved_next'.tr(),
        ),
      ],
      detour: SacStateStep(
        kind: fixing ? SacStateKind.rejected : SacStateKind.pending,
        title: 'certificate_import.status.group_fix'.tr(),
        detail: fixing
            ? _plural('certificate_import.status.corrections', state.toFixCount)
            : 'certificate_import.status.fix_hint'.tr(),
      ),
      kindLabels: SacStateKindLabels(
        done: 'certificate_import.status.kind_done'.tr(),
        current: 'certificate_import.status.kind_current'.tr(),
        rejected: 'certificate_import.status.kind_rejected'.tr(),
        pending: 'certificate_import.status.kind_pending'.tr(),
      ),
    );
  }
}
