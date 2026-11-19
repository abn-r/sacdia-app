import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../investiture/domain/entities/investiture_status.dart';
import '../../../investiture_requests/presentation/widgets/own_investiture_row.dart';
import '../../domain/entities/class_module_detail.dart';
import '../../domain/entities/class_prerequisite.dart';
import '../../domain/entities/class_requirement.dart';
import '../../domain/entities/class_with_progress.dart';
import '../providers/classes_providers.dart';
import '../utils/open_class_requirement.dart';
import '../widgets/class_detail_header.dart';
import '../widgets/class_detail_sections.dart';
import '../widgets/class_summary_box.dart';
import '../widgets/grouped_class_skeleton.dart';
import '../widgets/grouped_summary_box.dart';

/// Class screen: header, one summary box (validated of total with the
/// composition bar), what needs attention, the modules and the suggested
/// honors. Each module opens its own screen ([RouteNames.classModule]).
/// Pull-to-refresh, skeleton, error with retry.
///
/// With [targetUserId] a coach or director sees a member's class.
class ClassDetailWithProgressView extends ConsumerWidget {
  final int classId;
  final int? enrollmentId;
  final String? targetUserId;

  const ClassDetailWithProgressView({
    super.key,
    required this.classId,
    this.enrollmentId,
    this.targetUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressQuery = ClassProgressQuery(
      classId: classId,
      enrollmentId: enrollmentId,
      targetUserId: targetUserId,
    );
    final classAsync = ref.watch(classWithProgressProvider(progressQuery));
    final prerequisitesAsync = ref.watch(classDetailProvider(classId));
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: 'classes.detail_with_progress.title'.tr(),
        backgroundColor: c.canvas,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: classAsync.when(
              loading: () => const GroupedClassSkeleton(rows: 5),
              error: (error, _) => SacErrorState(
                title: 'classes.detail_with_progress.error_loading'.tr(),
                message: userErrorMessage(error),
                padding: SacTopBar.paddingBelowBar(
                  context,
                  const EdgeInsets.all(32),
                ),
                onRetry: () =>
                    ref.invalidate(classWithProgressProvider(progressQuery)),
              ),
              data: (classWithProgress) => _ClassBody(
                classWithProgress: classWithProgress,
                classId: classId,
                enrollmentId: enrollmentId ?? classWithProgress.enrollmentId,
                targetUserId: targetUserId,
                prerequisites:
                    prerequisitesAsync.value?.prerequisites ?? const [],
                onRefresh: () async {
                  ref.invalidate(classWithProgressProvider(progressQuery));
                  ref.invalidate(classDetailProvider(classId));
                  ref.invalidate(classHonorsProvider(classId));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────────

class _ClassBody extends StatelessWidget {
  final ClassWithProgress classWithProgress;
  final int classId;
  final int? enrollmentId;
  final String? targetUserId;
  final List<ClassPrerequisite> prerequisites;
  final Future<void> Function() onRefresh;

  const _ClassBody({
    required this.classWithProgress,
    required this.classId,
    this.enrollmentId,
    this.targetUserId,
    this.prerequisites = const [],
    required this.onRefresh,
  });

  void _openRequirement(BuildContext context, ClassRequirement requirement) {
    openClassRequirement(
      context,
      requirement: requirement,
      classData: classWithProgress,
      classId: classId,
      enrollmentId: enrollmentId,
      targetUserId: targetUserId,
    );
  }

  void _openModule(BuildContext context, ClassModuleDetail module) {
    context.push<void>(
      RouteNames.classModulePath(
        '$classId',
        '${module.id}',
        enrollmentId: enrollmentId,
        targetUserId: targetUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classData = classWithProgress;
    final investitureStatus = _investitureStatusOf(classData);
    // Quien mira su propia clase ve UNA fila de investidura (estado de la
    // autorización, o «Investido» si la clase se acreditó sin ese flujo).
    final isOwnView = targetUserId == null;
    final modules = [
      for (final m in classData.modules)
        if (m.requirements.isNotEmpty) m,
    ];

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
          SliverToBoxAdapter(child: ClassDetailHeader(classData: classData)),
          if (classData.isExpired || prerequisites.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Column(
                  children: [
                    if (classData.isExpired) const _ExpiredTrajectoryBanner(),
                    if (prerequisites.isNotEmpty)
                      _PrerequisitesBanner(prerequisites: prerequisites),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: KeyedSubtree(
                key: const ValueKey('class-summary'),
                child: ClassSummaryBox(
                  label: 'classes.detail_with_progress.summary_label'.tr(),
                  requirements: classData.allRequirements,
                  footer: _SummaryFooter(classData: classData),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: OwnInvestitureRow(
                classId: classId,
                isOwnView: isOwnView,
                enrollmentInvested:
                    investitureStatus == InvestitureStatus.investido,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ClassAttentionSection(
              modules: modules,
              onOpenRequirement: (r) => _openRequirement(context, r),
            ),
          ),
          if (modules.isEmpty)
            SliverToBoxAdapter(
              child: SacEmptyState(
                title: 'classes.detail_with_progress.empty_modules_title'.tr(),
                body: 'classes.detail_with_progress.empty_modules_body'.tr(),
                icon: HugeIcons.strokeRoundedSchool,
              ),
            )
          else
            SliverToBoxAdapter(
              child: ClassModulesSection(
                modules: modules,
                onOpenModule: (m) => _openModule(context, m),
              ),
            ),
          SliverToBoxAdapter(
            child: ClassRecommendedHonorsSection(classId: classId),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

/// Under the bar: the investiture percentage and, when the class has an
/// advanced section, its independent progress.
class _SummaryFooter extends StatelessWidget {
  const _SummaryFooter({required this.classData});

  final ClassWithProgress classData;

  @override
  Widget build(BuildContext context) {
    final advanced = classData.hasAdvancedTrackData
        ? (classData.advancedProgress?.percentage ?? 0).clamp(0, 100).toInt()
        : null;
    return Column(
      children: [
        GroupedKeyValueLine(
          label: 'classes.grouped.investiture_progress'.tr(),
          value: groupedPercentText(classData.investitureProgressPercent),
        ),
        if (advanced != null) ...[
          const SizedBox(height: 8),
          GroupedKeyValueLine(
            label: 'classes.detail_with_progress.advanced_progress'.tr(),
            value: groupedPercentText(advanced),
          ),
        ],
      ],
    );
  }
}

InvestitureStatus _investitureStatusOf(ClassWithProgress classData) {
  final raw = classData.investitureStatus;
  if (raw == null || raw.trim().isEmpty) {
    return InvestitureStatus.inProgress;
  }
  return InvestitureStatus.fromString(raw);
}

class _ExpiredTrajectoryBanner extends StatelessWidget {
  const _ExpiredTrajectoryBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Text(
        'classes.requirement_detail.expired_banner'.tr(),
        style: TextStyle(
          fontSize: SacFontSize.bodySmall,
          fontWeight: FontWeight.w600,
          color: c.onErrorContainer,
          height: 1.35,
        ),
      ),
    );
  }
}

class _PrerequisitesBanner extends StatelessWidget {
  final List<ClassPrerequisite> prerequisites;

  const _PrerequisitesBanner({required this.prerequisites});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final names = prerequisites.map((p) => p.name).join(', ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.infoContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            size: 18,
            color: c.onInfoContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  fontWeight: FontWeight.w600,
                  color: c.onInfoContainer,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text:
                        '${'classes.detail_with_progress.requires_label'.tr()} ',
                  ),
                  TextSpan(
                    text: names,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
