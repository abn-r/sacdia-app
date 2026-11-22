import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/theme/sac_font_size.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../classes/presentation/widgets/grouped_class_skeleton.dart';
import '../../domain/entities/certification_module.dart';
import '../../domain/entities/certification_progress.dart';
import '../providers/certifications_providers.dart';
import '../utils/certification_status_view.dart';
import '../widgets/certification_requirement_row.dart';
import '../widgets/certification_summary_box.dart';

/// One module of a certification: its progress and its requirements grouped
/// by state (to fix, not sent, sent, validated). Opened by id: it reads the
/// module from the certification progress, so coming back from a requirement
/// (which invalidates it) the list is already up to date.
///
/// Before enrolling it lists the module's requirements read-only.
/// Route: `/certification/:certificationId/module/:moduleId`.
class CertificationModuleView extends ConsumerWidget {
  const CertificationModuleView({
    super.key,
    required this.certificationId,
    required this.moduleId,
  });

  final int certificationId;
  final int moduleId;

  String _groupLabel(CertificationRequirementGroup group) => switch (group) {
        CertificationRequirementGroup.toFix =>
          'certifications.status.rejected'.tr(),
        CertificationRequirementGroup.unsent =>
          'certifications.status.pending'.tr(),
        CertificationRequirementGroup.sent =>
          'certifications.module.group_sent'.tr(),
        CertificationRequirementGroup.validated =>
          'certifications.module.group_validated'.tr(),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(userCertificationsProvider);
    final enrollment = activeEnrollmentFor(
      enrollmentsAsync.value ?? const [],
      certificationId,
    );
    final progressAsync = enrollment == null
        ? null
        : ref.watch(certificationProgressProvider(certificationId));
    final detailAsync = enrollment != null
        ? null
        : ref.watch(certificationDetailProvider(certificationId));

    ModuleProgress? module;
    for (final m in progressAsync?.value?.modules ?? const <ModuleProgress>[]) {
      if (m.moduleId == moduleId) module = m;
    }
    CertificationModule? catalogModule;
    for (final m
        in detailAsync?.value?.modules ?? const <CertificationModule>[]) {
      if (m.moduleId == moduleId) catalogModule = m;
    }

    final String? name = module?.moduleName ?? catalogModule?.name;
    String? subtitle;
    if (module != null) {
      final counts = countSections(module.sections);
      subtitle = 'certifications.module.subtitle'.tr(
        namedArgs: {
          'done': '${counts.validated}',
          'total': '${counts.total}',
        },
      );
    } else if (catalogModule != null) {
      subtitle = 'certifications.common.requirements'
          .plural(catalogModule.sections.length);
    }

    final loaded = enrollmentsAsync.value != null &&
        (enrollment != null
            ? progressAsync?.value != null
            : detailAsync?.value != null);
    final failure = enrollmentsAsync.hasError
        ? enrollmentsAsync.error
        : (progressAsync?.hasError ?? false)
            ? progressAsync?.error
            : detailAsync?.error;

    void retry() {
      ref.invalidate(userCertificationsProvider);
      ref.invalidate(certificationProgressProvider(certificationId));
      ref.invalidate(certificationDetailProvider(certificationId));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: name ?? 'certifications.view.title'.tr(),
        subtitle: subtitle,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            if (!loaded) {
              if (failure != null) {
                return SacErrorState(
                  title: 'certifications.view.error_loading'.tr(),
                  message: userErrorMessage(failure),
                  padding: SacTopBar.paddingBelowBar(
                    context,
                    const EdgeInsets.all(32),
                  ),
                  onRetry: retry,
                );
              }
              return const GroupedClassSkeleton(rows: 5);
            }
            if (module == null && catalogModule == null) {
              return Padding(
                padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
                child: SacEmptyState(
                  key: const ValueKey('certification-module-not-found'),
                  icon: HugeIcons.strokeRoundedSearch01,
                  title: 'certifications.module.not_found_title'.tr(),
                  body: 'certifications.module.not_found_body'.tr(),
                ),
              );
            }
            return RefreshIndicator(
              color: SacAccent.of(context).color,
              edgeOffset: SacTopBar.frostedInset(context),
              onRefresh: () async => retry(),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: SacTopBar.frostedInset(context)),
                  ),
                  if (module != null)
                    ..._enrolledSlivers(
                      context,
                      module,
                      enrollmentId: enrollment!.enrollmentId,
                    )
                  else
                    ..._readOnlySlivers(context, catalogModule!),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _enrolledSlivers(
    BuildContext context,
    ModuleProgress module, {
    required int enrollmentId,
  }) {
    final groups = groupCertificationSections(module.sections);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: SacEntrance(
            index: 0,
            child: KeyedSubtree(
              key: const ValueKey('certification-module-summary'),
              child: CertificationSummaryBox(
                counts: countSections(module.sections),
              ),
            ),
          ),
        ),
      ),
      if (groups.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Text(
              'certifications.module.empty'.tr(),
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
              key: ValueKey('certification-module-group-${group.name}'),
              label: _groupLabel(group),
              children: [
                for (final s in items)
                  CertificationRequirementRow(
                    section: s,
                    onTap: () => context.push<void>(
                      RouteNames.certificationRequirementDetailPath(
                        certificationId,
                        s.sectionId,
                        enrollmentId: enrollmentId,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _readOnlySlivers(
    BuildContext context,
    CertificationModule module,
  ) {
    final description = module.description?.trim() ?? '';
    return [
      if (description.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              description,
              style: TextStyle(
                fontSize: SacFontSize.titleMedium,
                height: 1.45,
                color: context.sac.text,
              ),
            ),
          ),
        ),
      if (module.sections.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Text(
              'certifications.module.empty'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: context.sac.textSecondary,
              ),
            ),
          ),
        )
      else
        SliverToBoxAdapter(
          child: SacEntrance(
            index: 0,
            child: SacGroupedSection(
              key: const ValueKey('certification-module-readonly'),
              label: 'certifications.module.group_requirements'.tr(),
              children: [
                for (final s in module.sections)
                  _ReadOnlyRequirementRow(
                    key: ValueKey('certification-readonly-${s.sectionId}'),
                    name: s.name,
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}

/// A requirement of a certification the person has not enrolled in: its name,
/// nothing to open.
class _ReadOnlyRequirementRow extends StatelessWidget {
  const _ReadOnlyRequirementRow({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = SacStatusStyle.of(
      context,
      SacStatusKind.pending,
      label: name,
    );
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: name,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.container,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: style.icon,
                  size: 17,
                  color: style.onContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
