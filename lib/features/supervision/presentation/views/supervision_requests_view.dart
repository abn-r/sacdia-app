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
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_request.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_requests_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_request_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_row_parts.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_segmented_control.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_status_chip.dart';

const double _kMaxContentWidth = 640;

/// Longest rejection reason a result chip carries; longer ones read in the
/// request sheet and the chip says only «Rechazada».
const int _kChipReasonMaxLength = 28;

/// The three views of the screen: what waits, by kind, and what is resolved.
enum _RequestsSegment { transfers, assignments, resolved }

/// Transfer and role-assignment requests of the territory.
///
/// Opens on the transfers that wait for a review; «Cargos» shows the role
/// assignments and «Resueltas» the approved and rejected ones of both kinds.
/// A row opens the request in a sheet, where an actor holding
/// `requests.review_territory` approves or rejects it.
class SupervisionRequestsView extends ConsumerStatefulWidget {
  const SupervisionRequestsView({super.key});

  @override
  ConsumerState<SupervisionRequestsView> createState() =>
      _SupervisionRequestsViewState();
}

class _SupervisionRequestsViewState
    extends ConsumerState<SupervisionRequestsView> {
  _RequestsSegment _segment = _RequestsSegment.transfers;

  bool get _decided => _segment == _RequestsSegment.resolved;

  SupervisionRequestKind get _kind => _segment == _RequestsSegment.assignments
      ? SupervisionRequestKind.assignment
      : SupervisionRequestKind.transfer;

  List<SupervisionRequestsQuery> get _queries => _decided
      ? [
          for (final kind in SupervisionRequestKind.values) ...[
            SupervisionRequestsQuery(
              kind: kind,
              status: SupervisionRequestStatus.approved,
            ),
            SupervisionRequestsQuery(
              kind: kind,
              status: SupervisionRequestStatus.rejected,
            ),
          ],
        ]
      : [
          SupervisionRequestsQuery(
            kind: _kind,
            status: SupervisionRequestStatus.pending,
          ),
        ];

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

  /// One async value for the list on screen: the resolved segment merges the
  /// approved and the rejected requests of both kinds, newest decision first.
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
              padding: const EdgeInsets.only(bottom: 32),
              sliver: SliverToBoxAdapter(
                child: SacGroupedSection(
                  label: (_decided
                          ? 'supervision.requests.group_resolved'
                          : 'supervision.requests.group_to_review')
                      .tr(),
                  children: [
                    for (final request in items)
                      _RequestRow(
                        key: ValueKey('${request.kind.name}-${request.id}'),
                        request: request,
                        onTap: () =>
                            showSupervisionRequestSheet(context, request),
                      ),
                  ],
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
                    const EdgeInsets.only(top: 0),
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SupervisionSegmentedControl<_RequestsSegment>(
                      selected: _segment,
                      onChanged: (segment) =>
                          setState(() => _segment = segment),
                      segments: [
                        SupervisionSegment(
                          value: _RequestsSegment.transfers,
                          label: 'supervision.requests.kind_transfers'.tr(),
                          count: pendingCounts?.transfers,
                        ),
                        SupervisionSegment(
                          value: _RequestsSegment.assignments,
                          label: 'supervision.requests.kind_assignments'.tr(),
                          count: pendingCounts?.roleAssignments,
                        ),
                        SupervisionSegment(
                          value: _RequestsSegment.resolved,
                          label: 'supervision.requests.filter_decided'.tr(),
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

// ── Rows ────────────────────────────────────────────────────────────────────

/// A request: the person, the move or the role in one line, and (resolved)
/// the result as a chip.
class _RequestRow extends StatelessWidget {
  const _RequestRow({super.key, required this.request, required this.onTap});

  final SupervisionRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final status = request.status;
    final decided = status == SupervisionRequestStatus.approved ||
        status == SupervisionRequestStatus.rejected;
    final line = Text(
      _routeLine(request),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: SacFontSize.bodyMedium,
        height: 1.3,
        color: c.textSecondary,
      ),
    );
    return SacListRow(
      leading: SacMemberAvatar(name: request.personName, size: 40),
      title: request.personName,
      subtitleWidget: decided
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line,
                const SizedBox(height: 6),
                _ResultChip(request: request),
              ],
            )
          : line,
      trailing: SupervisionRowAge(
        when: decided ? request.reviewedAt : request.createdAt,
        absolute: decided,
      ),
      onTap: onTap,
    );
  }
}

/// «Orión › Vega» for a transfer, «Subdirectora en Orión» for an assignment.
String _routeLine(SupervisionRequest request) {
  final unknown = 'supervision.requests.unknown_club'.tr();
  String name(String? value) =>
      value == null || value.trim().isEmpty ? unknown : value.trim();
  switch (request.kind) {
    case SupervisionRequestKind.transfer:
      return '${name(request.fromClubName)} › ${name(request.toClubName)}';
    case SupervisionRequestKind.assignment:
      return 'supervision.requests.assignment_summary'.tr(args: [
        request.roleName ?? 'supervision.requests.unknown_role'.tr(),
        name(request.clubName),
      ]);
  }
}

/// «Aprobada» or «Rechazada»; a short rejection reason replaces the second.
class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.request});

  final SupervisionRequest request;

  @override
  Widget build(BuildContext context) {
    if (request.status == SupervisionRequestStatus.approved) {
      return SupervisionStatusChip(
        label: 'supervision.requests.approved'.tr(),
        icon: HugeIcons.strokeRoundedTick02,
        tone: SacTone.success,
      );
    }
    final comment = request.reviewComment?.trim() ?? '';
    return SupervisionStatusChip(
      label: comment.isNotEmpty && comment.length <= _kChipReasonMaxLength
          ? comment
          : 'supervision.requests.rejected'.tr(),
      icon: HugeIcons.strokeRoundedCancel01,
      tone: SacTone.error,
    );
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
      title: (decided
              ? 'supervision.requests.empty_decided_title'
              : 'supervision.requests.empty_${stateKey}_${kindKey}_title')
          .tr(),
      body: 'supervision.requests.empty_${stateKey}_body'.tr(),
    );
  }
}
