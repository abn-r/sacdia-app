import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_network_image.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/class_honor.dart';
import '../../domain/entities/class_module_detail.dart';
import '../../domain/entities/class_requirement.dart';
import '../providers/classes_providers.dart';
import '../utils/class_requirement_groups.dart';
import 'class_module_row.dart';
import 'requirement_card.dart';

/// "Por atender": what was sent back first, then what is started but not
/// sent. Nothing is drawn when there is nothing to attend.
class ClassAttentionSection extends StatelessWidget {
  const ClassAttentionSection({
    super.key,
    required this.modules,
    required this.onOpenRequirement,
  });

  final List<ClassModuleDetail> modules;
  final void Function(ClassRequirement requirement) onOpenRequirement;

  @override
  Widget build(BuildContext context) {
    final items = attentionRequirements(modules);
    if (items.isEmpty) return const SizedBox.shrink();
    return SacGroupedSection(
      key: const ValueKey('class-attention-section'),
      label: 'classes.grouped.group_attention'.tr(),
      children: [
        for (final r in items)
          RequirementCard(
            requirement: r,
            showUnsentFiles: true,
            onTap: () => onOpenRequirement(r),
          ),
      ],
    );
  }
}

/// "Módulos": one row per module, no accordions. The module screen lists its
/// requirements.
class ClassModulesSection extends StatelessWidget {
  const ClassModulesSection({
    super.key,
    required this.modules,
    required this.onOpenModule,
  });

  final List<ClassModuleDetail> modules;
  final void Function(ClassModuleDetail module) onOpenModule;

  @override
  Widget build(BuildContext context) {
    return SacGroupedSection(
      key: const ValueKey('class-modules-section'),
      label: 'classes.detail_with_progress.modules_title'.tr(),
      children: [
        for (final m in modules)
          ClassModuleRow(
            key: ValueKey('class-module-${m.id}'),
            module: m,
            onTap: () => onOpenModule(m),
          ),
      ],
    );
  }
}

/// Honors the class suggests, as rows. Hidden while loading, on error or
/// when there are none.
class ClassRecommendedHonorsSection extends ConsumerWidget {
  const ClassRecommendedHonorsSection({super.key, required this.classId});

  final int classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honors = ref.watch(classHonorsProvider(classId)).value;
    if (honors == null) return const SizedBox.shrink();
    final suggested = ClassHonor.forClassCarousel(honors);
    if (suggested.isEmpty) return const SizedBox.shrink();
    return SacGroupedSection(
      key: const ValueKey('class-honors-section'),
      label: 'classes.detail_with_progress.recommended_title'.tr(),
      children: [
        for (final honor in suggested)
          ClassHonorRow(
            honor: honor,
            onTap: () => context.push(
              RouteNames.honorDetailPath(honor.honorId.toString()),
            ),
          ),
      ],
    );
  }
}

String classHonorRelationLabel(ClassHonorRelationType type) {
  switch (type) {
    case ClassHonorRelationType.required:
      return 'classes.detail_with_progress.honor_relation_required'.tr();
    case ClassHonorRelationType.elective:
      return 'classes.detail_with_progress.honor_relation_elective'.tr();
    case ClassHonorRelationType.recommended:
      return 'classes.detail_with_progress.honor_relation_recommended'.tr();
  }
}

/// A honor of the class: its badge, name and where it hangs (module or
/// relation to the class).
class ClassHonorRow extends StatelessWidget {
  const ClassHonorRow({super.key, required this.honor, required this.onTap});

  final ClassHonor honor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final moduleName = honor.moduleName?.trim() ?? '';
    final detail = moduleName.isEmpty
        ? classHonorRelationLabel(honor.relationType)
        : moduleName;
    final image = honor.honorImage;
    final star = HugeIcon(
      icon: HugeIcons.strokeRoundedStar,
      size: 17,
      color: c.textSecondary,
    );

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: '${honor.honorName}. $detail',
      child: SacInkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                  ),
                  child: image == null
                      ? star
                      : SacNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => star,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        honor.honorName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (honor.isCompletedByUser) ...[
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    size: 18,
                    color: c.success,
                  ),
                  const SizedBox(width: 6),
                ],
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
