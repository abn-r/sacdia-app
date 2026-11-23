import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_frosted_footer.dart';
import '../../../../core/widgets/sac_list_row.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/sac_value_row.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/transfer_request.dart';
import '../providers/transfer_providers.dart';
import '../widgets/club_type_tile.dart';
import '../widgets/transfer_status.dart';
import 'transfer_requests_view.dart';

/// One request: its state once, what the director said, the move from one
/// club to the other and its details.
class TransferRequestDetailView extends ConsumerWidget {
  final String requestId;

  const TransferRequestDetailView({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final requestAsync = ref.watch(transferRequestDetailProvider(requestId));
    final request = requestAsync.value;
    // Another request already in review blocks a new one.
    final otherPending = ref
            .watch(myTransferRequestsProvider)
            .value
            ?.any((r) => r.status == TransferStatus.pending) ??
        false;

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: request == null
            ? 'transfers.title'.tr()
            : 'transfers.detail.title_to'
                .tr(namedArgs: {'club': transferDestination(request)}),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: requestAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (e, _) => SacErrorState(
          title: userErrorMessage(e),
          onRetry: () =>
              ref.invalidate(transferRequestDetailProvider(requestId)),
        ),
        data: (request) => _DetailBody(request: request),
      ),
      bottomNavigationBar: request?.status == TransferStatus.rejected &&
              !otherPending
          ? SacFrostedFooter(
              child: SacButton.outline(
                key: const ValueKey('transfer-try-other'),
                text: 'transfers.detail.try_other'.tr(),
                icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
                onPressed: () => TransferRequestsView.openNewRequest(context),
              ),
            )
          : null,
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.request});

  final TransferRequest request;

  @override
  Widget build(BuildContext context) {
    final club = transferDestination(request);
    final comment = request.reviewerComment?.trim();
    final reason = request.reason?.trim();
    final created = request.createdAt;
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: _StatePanel(request: request, club: club),
        ),
        if (comment != null && comment.isNotEmpty)
          SacGroupedSection(
            label: 'transfers.detail.reviewer_comment'.tr(),
            action: const SizedBox.shrink(),
            children: [_TextRow(text: comment)],
          ),
        SacGroupedSection(
          label: 'transfers.detail.move'.tr(),
          action: const SizedBox.shrink(),
          dividerIndent: 0,
          children: [_MoveBox(request: request)],
        ),
        SacGroupedSection(
          label: 'transfers.detail.details'.tr(),
          action: const SizedBox.shrink(),
          dividerIndent: 16,
          children: [
            if (created != null)
              SacValueRow(
                label: 'transfers.detail.sent'.tr(),
                value: transferDate(context, created, withTime: true),
              ),
            if (reason != null && reason.isNotEmpty)
              SacValueRow(
                label: 'transfers.detail.your_reason'.tr(),
                value: reason,
              ),
            SacValueRow(
              label: 'transfers.detail.folio'.tr(),
              value: request.folio,
            ),
          ],
        ),
      ],
    );
  }
}

/// The state, once: who decides (or decided) and when.
class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.request, required this.club});

  final TransferRequest request;
  final String club;

  @override
  Widget build(BuildContext context) {
    final reviewed = request.reviewedAt;
    final pending = request.status == TransferStatus.pending;
    final message = pending
        ? 'transfers.detail.pending_message'.tr(namedArgs: {'club': club})
        : reviewed == null
            ? 'transfers.detail.reviewed'.tr(namedArgs: {'club': club})
            : 'transfers.detail.reviewed_on'.tr(namedArgs: {
                'club': club,
                'date': transferDate(context, reviewed),
              });
    return SacStatePanel(
      key: const ValueKey('transfer-state-panel'),
      style: transferStatusStyle(context, request.status),
      title: 'transfers.status.${request.status.slug}'.tr(),
      message: message,
      stepLabel: pending
          ? 'transfers.states.step'.tr(namedArgs: {'step': '2', 'total': '3'})
          : 'transfers.states.all'.tr(),
      onTap: () => showTransferStatesSheet(context, request),
    );
  }
}

/// "From → to": the club the member leaves and the one they asked for.
class _MoveBox extends StatelessWidget {
  const _MoveBox({required this.request});

  final TransferRequest request;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final from = request.fromClubName?.trim();
    return Column(
      children: [
        if (from != null && from.isNotEmpty) ...[
          SacListRow(
            leading: ClubTypeTile(clubTypeName: request.fromSectionName),
            title: from,
            subtitle: request.fromSectionName,
          ),
          Container(
            height: 24,
            color: c.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowDown01,
                  size: 14,
                  color: c.textTertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  'transfers.detail.move_to'.tr().toUpperCase(),
                  style: TextStyle(
                    fontSize: SacFontSize.labelSmall,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
        SacListRow(
          leading: ClubTypeTile(clubTypeName: request.toSectionName),
          title: transferDestination(request),
          subtitle: request.toSectionName,
        ),
      ],
    );
  }
}

/// Free text inside a group (the director's comment).
class _TextRow extends StatelessWidget {
  const _TextRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: TextStyle(
          fontSize: SacFontSize.titleMedium,
          height: 1.4,
          color: context.sac.text,
        ),
      ),
    );
  }
}
