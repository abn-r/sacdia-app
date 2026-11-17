import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/progress_scope.dart';
import '../utils/grouped_class_status.dart';
import 'grouped_progress_row.dart';
import 'grouped_summary_box.dart';

/// Content of the grouped-class home: scope summary and one row per class.
/// Pull to refresh works in every state, including the empty one.
class GroupedScopeBody extends StatelessWidget {
  const GroupedScopeBody({
    super.key,
    required this.scope,
    required this.onRefresh,
    required this.onOpenClass,
    this.clubTypeName,
  });

  final ProgressScopeResult scope;

  /// Club type of the active section ("Conquistadores"), for the banner.
  final String? clubTypeName;
  final Future<void> Function() onRefresh;
  final void Function(ProgressScopeClass item) onOpenClass;

  @override
  Widget build(BuildContext context) {
    final isSection = scope.hasSectionWideAccess;

    if (scope.classes.isEmpty) {
      return RefreshIndicator(
        color: SacAccent.of(context).color,
        edgeOffset: SacTopBar.frostedInset(context),
        onRefresh: onRefresh,
        child: Padding(
          padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
          child: SacEmptyState(
            key: const ValueKey('grouped-scope-empty'),
            scrollable: true,
            icon: HugeIcons.strokeRoundedBookOpen01,
            title: isSection
                ? 'classes.grouped.empty_director_title'.tr()
                : 'classes.grouped.empty_counselor_title'.tr(),
            body: isSection
                ? 'classes.grouped.empty_director_body'.tr()
                : 'classes.grouped.empty_counselor_body'.tr(),
          ),
        ),
      );
    }

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
              child: _ScopeSummary(scope: scope, clubTypeName: clubTypeName),
            ),
          ),
          SliverToBoxAdapter(
            child: SacGroupedSection(
              key: const ValueKey('grouped-scope-classes'),
              label: 'classes.grouped.classes_eyebrow'.tr(),
              children: [
                for (final item in scope.classes)
                  _ClassRow(item: item, onTap: () => onOpenClass(item)),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _ScopeSummary extends StatelessWidget {
  const _ScopeSummary({required this.scope, required this.clubTypeName});

  final ProgressScopeResult scope;
  final String? clubTypeName;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final counts = scope.totalStatusCounts;
    final String banner;
    if (!scope.hasSectionWideAccess) {
      banner = 'classes.grouped.scope_assigned'.tr();
    } else if (clubTypeName != null && clubTypeName!.trim().isNotEmpty) {
      banner = 'classes.grouped.scope_section'
          .tr(namedArgs: {'clubType': clubTypeName!.trim()});
    } else {
      banner = 'classes.grouped.scope_section_generic'.tr();
    }

    return KeyedSubtree(
      key: const ValueKey('grouped-scope-summary'),
      child: GroupedSummaryBox(
        leading: Row(
          key: const ValueKey('grouped-scope-banner'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedView,
              size: 18,
              color: c.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(child: GroupedBoldText(banner)),
          ],
        ),
        label: 'classes.grouped.avg_progress'.tr(),
        value: groupedPercentText(scope.weightedAvgProgress),
        valueSuffix:
            groupedMembersInClasses(scope.totalMembers, scope.classes.length),
        counts: counts.toStatusCounts(),
        footer: GroupedKeyValueLine(
          label: 'classes.grouped.to_fix'.tr(),
          value: '${counts.rejected}',
          valueColor: counts.rejected > 0 ? c.onErrorContainer : null,
        ),
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.item, required this.onTap});

  final ProgressScopeClass item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final counselor = item.counselor;
    final members = 'classes.grouped.members_count'.plural(item.membersCount);

    return GroupedProgressRow(
      key: ValueKey('grouped-class-row-${item.classId}'),
      leading: const GroupedIconDot(icon: HugeIcons.strokeRoundedBookOpen01),
      title: item.name,
      detail: TextSpan(
        children: [
          TextSpan(text: '$members · '),
          counselor == null
              ? TextSpan(
                  text: 'classes.grouped.no_counselor'.tr(),
                  style: TextStyle(color: c.onErrorContainer),
                )
              : TextSpan(
                  text: 'classes.grouped.counselor_line'
                      .tr(namedArgs: {'name': counselor.name}),
                ),
        ],
      ),
      progress: item.avgProgress,
      onTap: onTap,
    );
  }
}
