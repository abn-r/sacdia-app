import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_filter_chip.dart';
import '../../../../core/widgets/sac_member_avatar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/class_members_progress.dart';
import '../utils/grouped_class_status.dart';
import 'grouped_people_cards.dart';
import 'grouped_progress_row.dart';
import 'grouped_summary_box.dart';

/// Filter of the members list.
enum GroupedMembersFilter { all, behind, fix }

/// Members of [result] that pass [filter], lowest progress first (the ones
/// that need help come first). Ties keep alphabetical order.
List<ClassMemberProgress> filterAndSortMembers(
  List<ClassMemberProgress> members,
  GroupedMembersFilter filter,
) {
  final filtered = members.where((m) {
    switch (filter) {
      case GroupedMembersFilter.all:
        return true;
      case GroupedMembersFilter.behind:
        return m.isBehind;
      case GroupedMembersFilter.fix:
        return m.hasRejected;
    }
  }).toList()
    ..sort((a, b) {
      final byProgress = a.overallProgress.compareTo(b.overallProgress);
      return byProgress != 0 ? byProgress : a.name.compareTo(b.name);
    });
  return filtered;
}

/// Content of a class: summary with its counselors, filters and the members.
class GroupedMembersBody extends StatelessWidget {
  const GroupedMembersBody({
    super.key,
    required this.result,
    required this.className,
    required this.filter,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onOpenMember,
  });

  final ClassMembersProgressResult result;
  final String className;
  final GroupedMembersFilter filter;
  final ValueChanged<GroupedMembersFilter> onFilterChanged;
  final Future<void> Function() onRefresh;
  final void Function(ClassMemberProgress member) onOpenMember;

  @override
  Widget build(BuildContext context) {
    if (result.members.isEmpty) {
      return RefreshIndicator(
        color: SacAccent.of(context).color,
        edgeOffset: SacTopBar.frostedInset(context),
        onRefresh: onRefresh,
        child: Padding(
          padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
          child: SacEmptyState(
            key: const ValueKey('grouped-members-empty'),
            scrollable: true,
            icon: HugeIcons.strokeRoundedUserGroup,
            title: 'classes.grouped.members_empty_title'.tr(),
            body: 'classes.grouped.members_empty_body'
                .tr(namedArgs: {'className': className}),
          ),
        ),
      );
    }

    final members = filterAndSortMembers(result.members, filter);
    final summary = result.summary;

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
                key: const ValueKey('grouped-members-summary'),
                child: GroupedSummaryBox(
                  label: 'classes.grouped.avg_progress'.tr(),
                  value: groupedPercentText(summary.avgProgress),
                  valueSuffix: 'classes.grouped.members_count'
                      .plural(result.members.length),
                  counts: summary.statusCounts.toStatusCounts(),
                  footerDivider: false,
                  footer: GroupedPeopleCards(
                    counselor: result.counselor,
                    assistant: result.assistant,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _FilterChips(filter: filter, onChanged: onFilterChanged),
          ),
          SliverToBoxAdapter(
            child: SacGroupedSection(
              key: const ValueKey('grouped-members-list'),
              label: 'classes.grouped.members_eyebrow'.tr(),
              count: members.length,
              children: members.isEmpty
                  ? [const _EmptyFilterRow()]
                  : [
                      for (final m in members)
                        _MemberRow(member: m, onTap: () => onOpenMember(m)),
                    ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.filter, required this.onChanged});

  final GroupedMembersFilter filter;
  final ValueChanged<GroupedMembersFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = {
      GroupedMembersFilter.all: 'classes.grouped.filter_all'.tr(),
      GroupedMembersFilter.behind: 'classes.grouped.filter_behind'.tr(),
      GroupedMembersFilter.fix: 'classes.grouped.filter_fix'.tr(),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: SacFilterChip.barHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            for (final entry in labels.entries) ...[
              SacFilterChip(
                key: ValueKey('grouped-filter-${entry.key.name}'),
                label: entry.value,
                selected: filter == entry.key,
                onTap: () => onChanged(entry.key),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyFilterRow extends StatelessWidget {
  const _EmptyFilterRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('grouped-members-filter-empty'),
      padding: const EdgeInsets.all(16),
      child: Text(
        'classes.grouped.filter_empty'.tr(),
        style: TextStyle(
          fontSize: SacFontSize.bodySmall,
          color: context.sac.textSecondary,
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.onTap});

  final ClassMemberProgress member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final counts = member.statusCounts;
    // Older servers send no status counts: the sections are the requirements.
    final hasCounts = counts.total > 0;
    final done = hasCounts ? counts.validated : member.completedSections;
    final total = hasCounts ? counts.total : member.totalSections;
    final name = member.name.isEmpty ? member.userId : member.name;
    final detail = 'classes.grouped.member_validated_of'
        .tr(namedArgs: {'done': '$done', 'total': '$total'});

    return GroupedProgressRow(
      key: ValueKey('grouped-member-row-${member.userId}'),
      leading: SacMemberAvatar(name: name, size: 32),
      title: name,
      detail: TextSpan(
        text: member.crossTypeEnrollment
            ? '$detail · ${'classes.members_progress.cross_type_chip'.tr()}'
            : detail,
      ),
      progress: member.overallProgress,
      onTap: onTap,
    );
  }
}
