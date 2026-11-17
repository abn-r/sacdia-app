import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/class_requirement.dart';
import '../../domain/entities/class_with_progress.dart';
import '../utils/grouped_class_status.dart';
import '../utils/member_requirement_groups.dart';
import 'grouped_summary_box.dart';

/// Content of a member's progress for the coach: what is ready, the bar and
/// the requirements grouped by what the coach has to do about them.
class GroupedMemberBody extends StatelessWidget {
  const GroupedMemberBody({
    super.key,
    required this.progress,
    required this.onRefresh,
    required this.onOpenRequirement,
  });

  final ClassWithProgress progress;
  final Future<void> Function() onRefresh;
  final void Function(ClassRequirement requirement) onOpenRequirement;

  @override
  Widget build(BuildContext context) {
    final requirements = progress.allRequirements;

    if (requirements.isEmpty) {
      return RefreshIndicator(
        color: SacAccent.of(context).color,
        edgeOffset: SacTopBar.frostedInset(context),
        onRefresh: onRefresh,
        child: Padding(
          padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
          child: SacEmptyState(
            key: const ValueKey('grouped-member-empty'),
            scrollable: true,
            icon: HugeIcons.strokeRoundedTask01,
            title: 'classes.grouped.member_empty_title'.tr(),
            body: 'classes.grouped.member_empty_body'.tr(),
          ),
        ),
      );
    }

    final counts = countRequirements(requirements);
    final groups = groupRequirements(requirements);
    final missing = counts.total - counts.validated;

    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: SacTopBar.frostedInset(context)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: KeyedSubtree(
                key: const ValueKey('grouped-member-summary'),
                child: GroupedSummaryBox(
                  label: 'classes.grouped.ready_label'.tr(),
                  value: 'classes.grouped.ready_count'.tr(namedArgs: {
                    'ready': '${counts.validated}',
                    'total': '${counts.total}',
                  }),
                  valueSuffix: missing > 0
                      ? 'classes.grouped.missing'.plural(missing)
                      : null,
                  counts: counts.toStatusCounts(),
                  footer: GroupedKeyValueLine(
                    label: 'classes.grouped.investiture_progress'.tr(),
                    value:
                        groupedPercentText(progress.investitureProgressPercent),
                  ),
                ),
              ),
            ),
          ),
          for (final (group, items) in groups)
            SliverToBoxAdapter(
              child: SacGroupedSection(
                key: ValueKey('grouped-member-group-${group.name}'),
                label: switch (group) {
                  MemberRequirementGroup.attention =>
                    'classes.grouped.group_attention'.tr(),
                  MemberRequirementGroup.review =>
                    'classes.grouped.group_review'.tr(),
                  MemberRequirementGroup.validated =>
                    'classes.grouped.group_validated'.tr(),
                },
                children: [
                  for (final r in items)
                    _RequirementRow(
                      requirement: r,
                      onTap: () => onOpenRequirement(r),
                    ),
                ],
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.requirement, required this.onTap});

  final ClassRequirement requirement;
  final VoidCallback onTap;

  String _date(DateTime? date) =>
      date == null ? '' : DateFormat('d MMM').format(date.toLocal());

  String _detail() {
    final r = requirement;
    switch (r.status) {
      case RequirementStatus.pendiente:
        return r.files.isEmpty
            ? 'classes.grouped.no_files'.tr()
            : 'classes.grouped.files_of'.tr(namedArgs: {
                'count': '${r.files.length}',
                'max': '${r.maxFiles}',
              });
      case RequirementStatus.rechazado:
      case RequirementStatus.observado:
        final note = (r.rejectionReason ?? r.observationComment ?? '').trim();
        return note.isEmpty
            ? 'classes.grouped.returned_default'.tr()
            : '«$note»';
      case RequirementStatus.enviado:
        return r.submittedAt == null
            ? 'classes.grouped.state_review'.tr()
            : 'classes.grouped.sent_on'
                .tr(namedArgs: {'date': _date(r.submittedAt)});
      case RequirementStatus.validado:
        return r.validatedAt == null
            ? 'classes.grouped.state_validated'.tr()
            : 'classes.grouped.validated_on'
                .tr(namedArgs: {'date': _date(r.validatedAt)});
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = requirement;
    return SacStatusRow(
      key: ValueKey('grouped-requirement-${r.id}'),
      style: requirementStatusStyle(context, r.status),
      title: r.name,
      detail: _detail(),
      detailIsError: requirementStatusKind(r.status) == SacStatusKind.rejected,
      onTap: onTap,
    );
  }
}
