import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/theme/sac_font_size.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/class_honor.dart';
import '../../domain/entities/class_module_detail.dart';
import '../../domain/entities/class_with_progress.dart';
import '../providers/classes_providers.dart';
import '../utils/class_requirement_groups.dart';
import '../utils/member_requirement_groups.dart';
import '../utils/open_class_requirement.dart';
import '../widgets/class_honor_actions.dart';
import '../widgets/class_summary_box.dart';
import '../widgets/grouped_class_skeleton.dart';
import '../widgets/requirement_card.dart';

/// One module of a class: its progress and its requirements grouped by
/// state (to fix, not sent, sent, validated). Opened by id, so it reads the
/// module from the class progress: coming back from a requirement the
/// provider was invalidated and the list is already up to date.
/// Route: `/class/:classId/module/:moduleId`.
class ClassModuleView extends ConsumerWidget {
  const ClassModuleView({
    super.key,
    required this.classId,
    required this.moduleId,
    this.enrollmentId,
    this.targetUserId,
  });

  final int classId;
  final int moduleId;
  final int? enrollmentId;
  final String? targetUserId;

  ClassProgressQuery get _query => ClassProgressQuery(
        classId: classId,
        enrollmentId: enrollmentId,
        targetUserId: targetUserId,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = _query;
    final progressAsync = ref.watch(classWithProgressProvider(query));
    final progress = progressAsync.value;

    ClassModuleDetail? module;
    for (final m in progress?.modules ?? const <ClassModuleDetail>[]) {
      if (m.id == moduleId) module = m;
    }

    final counts =
        module == null ? null : countRequirements(module.requirements);
    final subtitle = counts == null
        ? null
        : 'classes.detail_with_progress.module_subtitle'.tr(namedArgs: {
            'done': '${counts.validated}',
            'total': '${counts.total}',
          });

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: module?.name ?? 'classes.detail_with_progress.title'.tr(),
        subtitle: subtitle,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            final padding = SacTopBar.paddingBelowBar(
              context,
              const EdgeInsets.all(32),
            );
            if (progress == null) {
              if (progressAsync.hasError) {
                return SacErrorState(
                  title: 'classes.detail_with_progress.error_loading'.tr(),
                  message: userErrorMessage(progressAsync.error),
                  padding: padding,
                  onRetry: () =>
                      ref.invalidate(classWithProgressProvider(query)),
                );
              }
              return const GroupedClassSkeleton(rows: 5);
            }
            if (module == null) {
              return Padding(
                padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
                child: SacEmptyState(
                  key: const ValueKey('module-not-found'),
                  icon: HugeIcons.strokeRoundedSearch01,
                  title: 'classes.detail_with_progress.module_not_found_title'
                      .tr(),
                  body:
                      'classes.detail_with_progress.module_not_found_body'.tr(),
                ),
              );
            }
            return _ModuleBody(
              module: module,
              classData: progress,
              classId: classId,
              enrollmentId: enrollmentId,
              targetUserId: targetUserId,
              onRefresh: () async {
                ref.invalidate(classWithProgressProvider(query));
                ref.invalidate(classHonorsProvider(classId));
                try {
                  await ref.read(classWithProgressProvider(query).future);
                } catch (_) {
                  // The error state of the provider already shows it.
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class _ModuleBody extends ConsumerWidget {
  const _ModuleBody({
    required this.module,
    required this.classData,
    required this.classId,
    required this.onRefresh,
    this.enrollmentId,
    this.targetUserId,
  });

  final ClassModuleDetail module;
  final ClassWithProgress classData;
  final int classId;
  final int? enrollmentId;
  final String? targetUserId;
  final Future<void> Function() onRefresh;

  String _label(ModuleRequirementGroup group) => switch (group) {
        ModuleRequirementGroup.toFix => 'classes.grouped.state_rejected'.tr(),
        ModuleRequirementGroup.unsent => 'classes.grouped.state_pending'.tr(),
        ModuleRequirementGroup.sent =>
          'classes.detail_with_progress.group_sent'.tr(),
        ModuleRequirementGroup.validated =>
          'classes.grouped.group_validated'.tr(),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honors =
        (ref.watch(classHonorsProvider(classId)).value ?? const <ClassHonor>[])
            .where((h) => h.moduleId == module.id)
            .toList();
    final groups = groupModuleRequirements(module.requirements);

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
              child: SacEntrance(
                index: 0,
                child: KeyedSubtree(
                  key: const ValueKey('module-summary'),
                  child: ClassSummaryBox(requirements: module.requirements),
                ),
              ),
            ),
          ),
          if (groups.isEmpty && honors.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Text(
                  'classes.detail_with_progress.empty_requirements'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    color: context.sac.textSecondary,
                  ),
                ),
              ),
            ),
          for (final (i, (group, items)) in groups.indexed)
            SliverToBoxAdapter(
              child: SacEntrance(
                index: i + 1,
                child: SacGroupedSection(
                  key: ValueKey('module-group-${group.name}'),
                  label: _label(group),
                  children: [
                    for (final r in items)
                      RequirementCard(
                        requirement: r,
                        onTap: () => openClassRequirement(
                          context,
                          requirement: r,
                          classData: classData,
                          classId: classId,
                          enrollmentId: enrollmentId,
                          targetUserId: targetUserId,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (honors.isNotEmpty)
            SliverToBoxAdapter(
              child: SacEntrance(
                index: groups.length + 1,
                child: SacGroupedSection(
                  key: const ValueKey('module-honors'),
                  label: 'classes.honors.module_section'.tr(),
                  dividerIndent: 14,
                  children: [
                    for (final honor in honors)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 2),
                        child: ClassHonorActionsRow(honor: honor),
                      ),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
