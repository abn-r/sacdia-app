import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
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
import 'package:sacdia_app/features/supervision/domain/entities/supervision_request.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_requests_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_card_header.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_decision_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';

const double _kMaxContentWidth = 640;

/// Server limit of a review comment.
const int _kCommentMaxLength = 500;

/// Transfer and role-assignment requests of the territory.
///
/// Opens on what waits for a review; "Resueltas" shows the approved and
/// rejected ones instead. A card opens the request in a sheet, where an actor
/// holding `requests.review_territory` approves or rejects it.
class SupervisionRequestsView extends ConsumerStatefulWidget {
  const SupervisionRequestsView({super.key});

  @override
  ConsumerState<SupervisionRequestsView> createState() =>
      _SupervisionRequestsViewState();
}

class _SupervisionRequestsViewState
    extends ConsumerState<SupervisionRequestsView> {
  SupervisionRequestKind _kind = SupervisionRequestKind.transfer;
  bool _decided = false;

  SupervisionRequestsQuery _query(SupervisionRequestStatus status) =>
      SupervisionRequestsQuery(kind: _kind, status: status);

  List<SupervisionRequestsQuery> get _queries => _decided
      ? [
          _query(SupervisionRequestStatus.approved),
          _query(SupervisionRequestStatus.rejected),
        ]
      : [_query(SupervisionRequestStatus.pending)];

  Future<void> _refresh() async {
    final queries = _queries;
    ref.invalidate(supervisionRequestsProvider);
    ref.invalidate(supervisionPendingCountsProvider);
    for (final query in queries) {
      try {
        await ref.read(supervisionRequestsProvider(query).future);
      } catch (_) {
        // The error state renders the failure.
      }
    }
  }

  /// One async value for the list on screen: the resolved filter merges the
  /// approved and the rejected requests, newest decision first.
  AsyncValue<List<SupervisionRequest>> _watchRequests() {
    final parts = [
      for (final query in _queries)
        ref.watch(supervisionRequestsProvider(query)),
    ];
    for (final part in parts) {
      if (part.hasError && !part.isLoading) {
        return AsyncError(part.error!, part.stackTrace ?? StackTrace.current);
      }
    }
    if (parts.any((part) => !part.hasValue)) return const AsyncLoading();
    final merged = [for (final part in parts) ...part.requireValue];
    if (_decided) {
      merged.sort((a, b) {
        final left = a.reviewedAt ?? a.createdAt;
        final right = b.reviewedAt ?? b.createdAt;
        if (left == null || right == null) return 0;
        return right.compareTo(left);
      });
    }
    return AsyncData(merged);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final requests = _watchRequests();
    final pendingCounts = ref.watch(supervisionPendingCountsProvider).value;

    final Widget content = requests.when(
      loading: () => const SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
        sliver: SliverToBoxAdapter(
          child: SacSkeletonList(
            itemCount: 5,
            leading: false,
            scrollable: false,
          ),
        ),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: isForbiddenFailure(error)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'supervision.requests.error_title'.tr(),
                message: 'supervision.requests.error_message'.tr(),
                onRetry: _refresh,
              ),
      ),
      data: (items) => items.isEmpty
          ? SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyRequests(kind: _kind, decided: _decided),
            )
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RequestCard(
                    request: items[index],
                    onTap: () => _showRequestSheet(context, items[index]),
                  ),
                ),
              ),
            ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'supervision.requests.title'.tr(),
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: SacAccent.of(context).color,
            edgeOffset: SacTopBar.frostedInset(context),
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: SacTopBar.paddingBelowBar(
                    context,
                    const EdgeInsets.only(top: 8),
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _RequestsFilter(
                      kind: _kind,
                      decided: _decided,
                      transfersPending: pendingCounts?.transfers,
                      assignmentsPending: pendingCounts?.roleAssignments,
                      onKind: (kind) => setState(() => _kind = kind),
                      onDecided: () => setState(() => _decided = !_decided),
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

// ── Filter ──────────────────────────────────────────────────────────────────

/// Kind of request (one or the other) and, set apart in the quiet style, the
/// switch between what waits and what was already resolved.
class _RequestsFilter extends StatelessWidget {
  const _RequestsFilter({
    required this.kind,
    required this.decided,
    required this.transfersPending,
    required this.assignmentsPending,
    required this.onKind,
    required this.onDecided,
  });

  final SupervisionRequestKind kind;
  final bool decided;
  final int? transfersPending;
  final int? assignmentsPending;
  final ValueChanged<SupervisionRequestKind> onKind;
  final VoidCallback onDecided;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SacFilterChip.barHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          Center(
            child: SacFilterChip(
              label: 'supervision.requests.kind_transfers'.tr(),
              selected: kind == SupervisionRequestKind.transfer,
              count: transfersPending,
              onTap: () => onKind(SupervisionRequestKind.transfer),
            ),
          ),
          const SizedBox(width: 8),
          Center(
            child: SacFilterChip(
              label: 'supervision.requests.kind_assignments'.tr(),
              selected: kind == SupervisionRequestKind.assignment,
              count: assignmentsPending,
              onTap: () => onKind(SupervisionRequestKind.assignment),
            ),
          ),
          const SizedBox(width: 20),
          Center(
            child: SacFilterChip(
              label: 'supervision.requests.filter_decided'.tr(),
              selected: decided,
              variant: SacFilterChipVariant.quiet,
              onTap: onDecided,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cards ───────────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final SupervisionRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pending = request.status == SupervisionRequestStatus.pending;
    final when = pending ? request.createdAt : request.reviewedAt;
    final outcome = _outcomeLine(request);

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: SacCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SupervisionCardHeader(title: request.personName, when: when),
              const SizedBox(height: 2),
              Text(
                _summaryLine(request),
                maxLines: 3,
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
                    color: request.status == SupervisionRequestStatus.rejected
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

/// "Club Orión (Conquistadores)", with whatever part the server sent.
String? _clubLabel(String? club, String? section) {
  final clubName = club?.trim() ?? '';
  final sectionName = section?.trim() ?? '';
  if (clubName.isEmpty && sectionName.isEmpty) return null;
  if (clubName.isEmpty) return sectionName;
  if (sectionName.isEmpty) return clubName;
  return '$clubName ($sectionName)';
}

/// What is being asked, in one sentence: where the member moves, or which
/// role in which club.
String _summaryLine(SupervisionRequest request) {
  final unknown = 'supervision.requests.unknown_club'.tr();
  switch (request.kind) {
    case SupervisionRequestKind.transfer:
      return 'supervision.requests.transfer_summary'.tr(args: [
        _clubLabel(request.fromClubName, request.fromSectionLabel) ?? unknown,
        _clubLabel(request.toClubName, request.toSectionLabel) ?? unknown,
      ]);
    case SupervisionRequestKind.assignment:
      return 'supervision.requests.assignment_summary'.tr(args: [
        request.roleName ?? 'supervision.requests.unknown_role'.tr(),
        _clubLabel(request.clubName, request.sectionLabel) ?? unknown,
      ]);
  }
}

String? _outcomeLine(SupervisionRequest request) {
  final reviewer = request.reviewerName?.trim();
  final hasReviewer = reviewer != null && reviewer.isNotEmpty;
  switch (request.status) {
    case SupervisionRequestStatus.approved:
      return hasReviewer
          ? 'supervision.requests.approved_by'.tr(args: [reviewer])
          : 'supervision.requests.approved'.tr();
    case SupervisionRequestStatus.rejected:
      final comment = request.reviewComment?.trim();
      if (comment != null && comment.isNotEmpty) return comment;
      return hasReviewer
          ? 'supervision.requests.rejected_by'.tr(args: [reviewer])
          : 'supervision.requests.rejected'.tr();
    case SupervisionRequestStatus.pending:
    case SupervisionRequestStatus.unknown:
      return null;
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests({required this.kind, required this.decided});

  final SupervisionRequestKind kind;
  final bool decided;

  @override
  Widget build(BuildContext context) {
    final kindKey =
        kind == SupervisionRequestKind.transfer ? 'transfers' : 'assignments';
    final stateKey = decided ? 'decided' : 'pending';
    return SacEmptyState(
      title: 'supervision.requests.empty_${stateKey}_${kindKey}_title'.tr(),
      body: 'supervision.requests.empty_${stateKey}_body'.tr(),
    );
  }
}

// ── Request sheet ───────────────────────────────────────────────────────────

Future<void> _showRequestSheet(
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
      message: _summaryLine(_request),
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
    final c = context.sac;
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final canReview = hasCapability(user, 'requests.review_territory') &&
        _request.status == SupervisionRequestStatus.pending;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(
            title: _request.personName,
            subtitle: (_isTransfer
                    ? 'supervision.requests.sheet_transfer'
                    : 'supervision.requests.sheet_assignment')
                .tr(),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: _RequestFacts(request: _request),
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
          if (canReview)
            ApprovalActionBar(
              isLoading: _busy,
              onApprove: () => _review(approve: true),
              onReject: () => _review(approve: false),
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
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    String date(DateTime when) => intl.DateFormat.yMMMd(locale).format(when);
    SacValueRow row(String key, String value) => SacValueRow(
          label: 'supervision.requests.$key'.tr(),
          value: value,
        );
    SacValueRow? optional(String key, String? value) =>
        value == null || value.trim().isEmpty ? null : row(key, value);

    final requestRows = <SacValueRow?>[
      if (request.kind == SupervisionRequestKind.transfer) ...[
        optional(
          'from',
          _clubLabel(request.fromClubName, request.fromSectionLabel),
        ),
        optional('to', _clubLabel(request.toClubName, request.toSectionLabel)),
        optional('reason', request.reason),
      ] else ...[
        optional('role', request.roleName),
        optional('club', _clubLabel(request.clubName, request.sectionLabel)),
        optional('requested_by', request.requestedByName),
      ],
      if (request.createdAt != null)
        row('created_at', date(request.createdAt!)),
    ].whereType<SacValueRow>().toList();

    final reviewRows = <SacValueRow?>[
      optional('reviewed_by', request.reviewerName),
      if (request.reviewedAt != null)
        row('reviewed_at', date(request.reviewedAt!)),
      optional('review_comment', request.reviewComment),
    ].whereType<SacValueRow>().toList();

    Widget group(String key, List<Widget> rows) => SacGroupedSection(
          label: 'supervision.requests.$key'.tr(),
          dividerIndent: 16,
          // A count of rows says nothing here.
          action: const SizedBox.shrink(),
          children: rows,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (requestRows.isNotEmpty) group('request_title', requestRows),
        if (reviewRows.isNotEmpty) group('review_title', reviewRows),
      ],
    );
  }
}
