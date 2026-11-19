import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
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
///
/// When a requirement drops out of the group (a data refresh after resending
/// it) its row collapses and fades ([SacMotion.standard]) instead of
/// jumping, and the count rolls.
class ClassAttentionSection extends StatefulWidget {
  const ClassAttentionSection({
    super.key,
    required this.modules,
    required this.onOpenRequirement,
  });

  final List<ClassModuleDetail> modules;
  final void Function(ClassRequirement requirement) onOpenRequirement;

  @override
  State<ClassAttentionSection> createState() => _ClassAttentionSectionState();
}

class _AttentionEntry {
  _AttentionEntry(this.requirement);

  ClassRequirement requirement;
  bool leaving = false;
}

class _ClassAttentionSectionState extends State<ClassAttentionSection> {
  late List<_AttentionEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = [
      for (final r in attentionRequirements(widget.modules)) _AttentionEntry(r),
    ];
  }

  @override
  void didUpdateWidget(ClassAttentionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fresh = attentionRequirements(widget.modules);
    final freshIds = {for (final r in fresh) r.id};
    final previous = _entries;
    final next = <_AttentionEntry>[
      for (final r in fresh)
        previous.firstWhere(
          (e) => e.requirement.id == r.id,
          orElse: () => _AttentionEntry(r),
        )
          ..requirement = r
          ..leaving = false,
    ];
    // Rows that left stay where they were until they finish collapsing.
    for (var i = 0; i < previous.length; i++) {
      final e = previous[i];
      if (freshIds.contains(e.requirement.id)) continue;
      e.leaving = true;
      next.insert(i < next.length ? i : next.length, e);
    }
    _entries = next;
  }

  void _remove(_AttentionEntry entry) {
    if (!mounted) return;
    setState(() => _entries.remove(entry));
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) return const SizedBox.shrink();
    return SacGroupedSection(
      key: const ValueKey('class-attention-section'),
      label: 'classes.grouped.group_attention'.tr(),
      count: _entries.where((e) => !e.leaving).length,
      rollCount: true,
      children: [
        for (final e in _entries)
          _CollapsingRow(
            key: ValueKey('attention-${e.requirement.id}'),
            collapsed: e.leaving,
            onCollapsed: () => _remove(e),
            child: RequirementCard(
              requirement: e.requirement,
              showUnsentFiles: true,
              onTap: () => widget.onOpenRequirement(e.requirement),
            ),
          ),
      ],
    );
  }
}

/// Collapses its child (height and opacity, [SacMotion.standard]) when
/// [collapsed] turns true, then calls [onCollapsed]. Reduced Motion fades
/// only.
class _CollapsingRow extends StatefulWidget {
  const _CollapsingRow({
    super.key,
    required this.collapsed,
    required this.onCollapsed,
    required this.child,
  });

  final bool collapsed;
  final VoidCallback onCollapsed;
  final Widget child;

  @override
  State<_CollapsingRow> createState() => _CollapsingRowState();
}

class _CollapsingRowState extends State<_CollapsingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.standard,
      value: 1,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && widget.collapsed) {
          widget.onCollapsed();
        }
      });
    _curved = CurvedAnimation(parent: _controller, curve: SacMotion.easeOut);
    if (widget.collapsed) _controller.reverse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = SacMotion.reduceMotionOf(context)
        ? SacMotion.reducedFade
        : SacMotion.standard;
  }

  @override
  void didUpdateWidget(_CollapsingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsed && !oldWidget.collapsed) {
      _controller.reverse();
    } else if (!widget.collapsed && oldWidget.collapsed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = _curved;
    final reduce = SacMotion.reduceMotionOf(context);
    final faded = FadeTransition(opacity: curved, child: widget.child);
    return IgnorePointer(
      ignoring: widget.collapsed,
      child: reduce
          ? faded
          : SizeTransition(
              sizeFactor: curved,
              alignment: Alignment.topCenter,
              child: faded,
            ),
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
        pressedScale: SacMotion.rowPressScale,
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
