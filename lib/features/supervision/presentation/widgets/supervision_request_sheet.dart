import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_move_box.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_request.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_requests_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_actions.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_decision_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_quote.dart';
import 'package:sacdia_app/features/transfers/presentation/widgets/club_type_tile.dart';

/// Server limit of a review comment.
const int _kCommentMaxLength = 500;

/// «Club Orión (Conquistadores)», with whatever part the server sent.
String? requestClubLabel(String? club, String? section) {
  final clubName = club?.trim() ?? '';
  final sectionName = section?.trim() ?? '';
  if (clubName.isEmpty && sectionName.isEmpty) return null;
  if (clubName.isEmpty) return sectionName;
  if (sectionName.isEmpty) return clubName;
  return '$clubName ($sectionName)';
}

/// What is being asked, in one sentence: where the member moves, or which
/// role in which club.
String requestSummaryLine(SupervisionRequest request) {
  final unknown = 'supervision.requests.unknown_club'.tr();
  switch (request.kind) {
    case SupervisionRequestKind.transfer:
      return 'supervision.requests.transfer_summary'.tr(args: [
        requestClubLabel(request.fromClubName, request.fromSectionLabel) ??
            unknown,
        requestClubLabel(request.toClubName, request.toSectionLabel) ?? unknown,
      ]);
    case SupervisionRequestKind.assignment:
      return 'supervision.requests.assignment_summary'.tr(args: [
        request.roleName ?? 'supervision.requests.unknown_role'.tr(),
        requestClubLabel(request.clubName, request.sectionLabel) ?? unknown,
      ]);
  }
}

/// Opens a request: the move (or the role) it asks for and, for an actor
/// holding `requests.review_territory` on a pending one, the review.
Future<void> showSupervisionRequestSheet(
  BuildContext context,
  SupervisionRequest request,
) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RequestSheet(request: request),
  );
}

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet({required this.request});

  final SupervisionRequest request;

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  bool _busy = false;
  String? _error;

  SupervisionRequest get _request => widget.request;

  bool get _isTransfer => _request.kind == SupervisionRequestKind.transfer;

  Future<void> _review({required bool approve}) async {
    final action = approve ? 'approve' : 'reject';
    final kind = _isTransfer ? 'transfer' : 'assignment';
    final comment = await showSupervisionDecisionSheet(
      context: context,
      title: 'supervision.requests.${action}_${kind}_title'.tr(),
      message: requestSummaryLine(_request),
      fieldLabel: 'supervision.requests.comment_label'.tr(),
      fieldHint: approve
          ? 'supervision.requests.comment_hint_approve'.tr()
          : 'supervision.requests.comment_hint_reject'.tr(),
      confirmLabel: 'coordinator.actions.$action'.tr(),
      maxLength: _kCommentMaxLength,
      destructive: !approve,
    );
    if (comment == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(supervisionRequestReviewerProvider)
        .review(_request, approve: approve, comment: comment);
    if (!mounted) return;
    if (result.ok) {
      SacSnackBar.show(
        context,
        'supervision.requests.${approve ? 'approved' : 'rejected'}_toast'.tr(),
        isSuccess: true,
      );
      Navigator.of(context).pop();
      return;
    }
    final code = result.errorCode ?? '';
    // Someone else already resolved it: nothing left to do in this sheet.
    if (code.endsWith('_ALREADY_REVIEWED') || code.endsWith('_NOT_FOUND')) {
      SacSnackBar.show(
        context,
        'supervision.requests.error_already_reviewed'.tr(),
        isError: true,
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = code == 'REQUEST_ROLE_SLOT_LIMIT_REACHED'
          ? 'supervision.requests.error_slot_limit'.tr()
          : supervisionErrorMessage(result.errorMessage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final canReview = hasCapability(user, 'requests.review_territory') &&
        _request.status == SupervisionRequestStatus.pending;
    final sent = _request.createdAt;
    final subtitle = [
      (_isTransfer
              ? 'supervision.requests.sheet_transfer'
              : 'supervision.requests.sheet_assignment')
          .tr(),
      if (sent != null) supervisionDayMonth(context, sent.toLocal()),
    ].join(' · ');

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(
            leading: SacMemberAvatar(name: _request.personName, size: 40),
            title: _request.personName,
            subtitle: subtitle,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: _RequestFacts(request: _request),
            ),
          ),
          if (_error != null) SupervisionInlineError(message: _error!),
          if (canReview)
            SupervisionSheetFooter(
              child: SupervisionStackedActions(
                primaryLabel: (_isTransfer
                        ? 'supervision.requests.approve_transfer_title'
                        : 'supervision.requests.approve_assignment_title')
                    .tr(),
                primaryIcon: HugeIcons.strokeRoundedTick02,
                onPrimary: () => _review(approve: true),
                secondaryLabel: 'coordinator.actions.reject'.tr(),
                secondaryIcon: HugeIcons.strokeRoundedCancel01,
                onSecondary: () => _review(approve: false),
                isLoading: _busy,
              ),
            )
          else
            const SafeArea(top: false, child: SizedBox(height: 4)),
        ],
      ),
    );
  }
}

class _RequestFacts extends StatelessWidget {
  const _RequestFacts({required this.request});

  final SupervisionRequest request;

  @override
  Widget build(BuildContext context) {
    String date(DateTime when) => supervisionShortDate(context, when);
    SacValueRow row(String key, String value) => SacValueRow(
          label: 'supervision.requests.$key'.tr(),
          value: value,
        );
    SacValueRow? optional(String key, String? value) =>
        value == null || value.trim().isEmpty ? null : row(key, value);

    final isTransfer = request.kind == SupervisionRequestKind.transfer;
    final reason = request.reason?.trim() ?? '';

    final assignmentRows = <SacValueRow?>[
      optional('role', request.roleName),
      optional(
          'club', requestClubLabel(request.clubName, request.sectionLabel)),
      optional('requested_by', request.requestedByName),
      if (request.createdAt != null)
        row('created_at', date(request.createdAt!)),
    ].whereType<SacValueRow>().toList();

    final reviewRows = <SacValueRow?>[
      optional('reviewed_by', request.reviewerName),
      if (request.reviewedAt != null)
        row('reviewed_at', date(request.reviewedAt!)),
      optional('review_comment', request.reviewComment),
    ].whereType<SacValueRow>().toList();

    final firstName = request.personName.trim().split(RegExp(r'\s+')).first;
    final toTitle = request.toClubName?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isTransfer) ...[
          SacGroupedSection(
            label: 'supervision.requests.move_title'.tr(),
            action: const SizedBox.shrink(),
            dividerIndent: 0,
            children: [
              SacMoveBox(
                connector: 'supervision.requests.move_to'.tr(),
                fromLeading:
                    ClubTypeTile(clubTypeName: request.fromSectionLabel),
                fromTitle: request.fromClubName,
                fromSubtitle: request.fromSectionLabel,
                toLeading: ClubTypeTile(clubTypeName: request.toSectionLabel),
                toTitle: toTitle.isEmpty
                    ? 'supervision.requests.unknown_club'.tr()
                    : toTitle,
                toSubtitle: request.toSectionLabel,
              ),
            ],
          ),
          if (reason.isNotEmpty)
            SupervisionQuote(
              label: 'supervision.requests.reason_of'.tr(args: [firstName]),
              text: reason,
              icon: HugeIcons.strokeRoundedBubbleChat,
              tone: SacTone.muted,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            ),
        ] else if (assignmentRows.isNotEmpty)
          SacGroupedSection(
            label: 'supervision.requests.request_title'.tr(),
            dividerIndent: 16,
            action: const SizedBox.shrink(),
            children: assignmentRows,
          ),
        if (reviewRows.isNotEmpty)
          SacGroupedSection(
            label: 'supervision.requests.review_title'.tr(),
            dividerIndent: 16,
            action: const SizedBox.shrink(),
            children: reviewRows,
          ),
      ],
    );
  }
}
