import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/class_honor.dart';
import '../../domain/entities/class_module.dart';
import '../../domain/entities/class_module_detail.dart';
import '../../domain/entities/class_requirement.dart';
import '../../domain/entities/class_section.dart';
import '../../domain/entities/requirement_track.dart';
import 'class_honor_actions.dart';
import 'mini_ring.dart';
import 'requirement_card.dart';
import 'section_checkbox.dart';

/// Módulo expandible — Estilo original (legacy, usado en pantallas antiguas).
///
/// SacCard con ExpansionTile, mini progress bar, badge "X/Y".
/// Mantener para [ClassModulesView] y [SectionDetailView] que aún lo usan.
class ModuleExpansionTile extends StatelessWidget {
  final ClassModule module;
  final Function(int sectionId, bool isCompleted) onSectionToggle;

  const ModuleExpansionTile({
    super.key,
    required this.module,
    required this.onSectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = module.sections.where((s) => s.isCompleted).length;
    final totalCount = module.sections.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final isComplete = completedCount == totalCount && totalCount > 0;
    final hasTrackData =
        module.sections.any((section) => section.requirementTrack != null);

    return SacCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isComplete
                  ? AppColors.secondaryLight
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isComplete
                  ? HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      size: 20,
                      color: AppColors.secondaryDark)
                  : Text(
                      '$completedCount/$totalCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
            ),
          ),
          title: Text(
            module.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: context.sac.borderLight,
                color: isComplete ? AppColors.secondary : AppColors.primary,
              ),
            ),
          ),
          children: [
            if (hasTrackData)
              ..._buildTrackGroupedSectionChildren()
            else
              ...module.sections.map(
                (section) => SectionCheckbox(
                  section: section,
                  onChanged: (isCompleted) {
                    onSectionToggle(section.id, isCompleted);
                  },
                ),
              ),
            if (module.honors.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Especialidades',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.sac.ink500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ...module.honors.map(
                (honor) => ClassHonorActionsRow(honor: honor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTrackGroupedSectionChildren() {
    final grouped = <RequirementTrack, List<ClassSection>>{
      RequirementTrack.basic: [],
      RequirementTrack.advanced: [],
      RequirementTrack.extra: [],
      RequirementTrack.unknown: [],
    };

    final sections = List<ClassSection>.from(module.sections)
      ..sort((a, b) {
        final trackWeightA =
            RequirementTrackMeta.sortWeight(a.requirementTrack);
        final trackWeightB =
            RequirementTrackMeta.sortWeight(b.requirementTrack);
        if (trackWeightA != trackWeightB) {
          return trackWeightA.compareTo(trackWeightB);
        }

        final aOrder = a.displayOrder ?? 1 << 20;
        final bOrder = b.displayOrder ?? 1 << 20;
        return aOrder.compareTo(bOrder);
      });

    for (final section in sections) {
      grouped[section.requirementTrack ?? RequirementTrack.unknown]!
          .add(section);
    }

    final trackEntries = [
      RequirementTrack.basic,
      RequirementTrack.advanced,
      RequirementTrack.extra,
      RequirementTrack.unknown,
    ];

    final children = <Widget>[];
    for (final track in trackEntries) {
      final requirements = grouped[track]!;
      if (requirements.isEmpty) continue;

      final isAdvanced = track == RequirementTrack.advanced;
      children.add(_TrackSectionHeader(
        label: RequirementTrackMeta.toLabel(track),
        isAdvanced: isAdvanced,
      ));

      children.addAll(
        requirements.map(
          (section) => SectionCheckbox(
            section: section,
            onChanged: (isCompleted) {
              onSectionToggle(section.id, isCompleted);
            },
          ),
        ),
      );
    }

    return children;
  }
}

class _TrackSectionHeader extends StatelessWidget {
  final String label;
  final bool isAdvanced;

  const _TrackSectionHeader({
    required this.label,
    required this.isAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = isAdvanced ? 'Avanzado' : null;
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 8, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: c.ink500,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: c.ink400,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nuevo diseño — usado en ClassDetailWithProgressView
// ─────────────────────────────────────────────────────────────────────────────

/// Fila de módulo expandible con MiniRing y lista de ReqLines.
///
/// Handoff §5.8–5.9: padding 14v·16h, MiniRing 36×36, chevron rotado 90° al abrir.
class ModuleDetailRow extends StatefulWidget {
  final ClassModuleDetail module;
  final List<ClassHonor> honors;
  final bool initiallyExpanded;

  /// Callback para tap en un requerimiento.
  final void Function(ClassRequirement requirement) onRequirementTap;

  const ModuleDetailRow({
    super.key,
    required this.module,
    this.honors = const [],
    this.initiallyExpanded = false,
    required this.onRequirementTap,
  });

  @override
  State<ModuleDetailRow> createState() => _ModuleDetailRowState();
}

class _ModuleDetailRowState extends State<ModuleDetailRow>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _chevronController;
  late Animation<double> _chevronAngle;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _chevronController = AnimationController(
      vsync: this,
      duration: SacMotion.standard,
      value: _expanded ? 1.0 : 0.0,
    );
    _chevronAngle = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _chevronController, curve: SacMotion.easeOut),
    );
    _expandAnimation = CurvedAnimation(
      parent: _chevronController,
      curve: SacMotion.easeOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chevronController.duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.standard;
  }

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _chevronController.forward();
    } else {
      _chevronController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final pending = module.requirements.length - module.completedCount;
    final c = context.sac;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Module header row
        InkWell(
          onTap: _toggle,
          splashColor: AppColors.coral200.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                // MiniRing 36×36
                MiniRing(
                  progress: module.completionRatio,
                  size: 36,
                ),

                const SizedBox(width: 12),

                // Title + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        module.name,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${module.completedCount}/${module.requirements.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.ink500,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '·',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.ink300,
                              ),
                            ),
                          ),
                          Text(
                            '$pending pendientes',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.ink500,
                            ),
                          ),
                          if (widget.honors.isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '·',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.ink300,
                                ),
                              ),
                            ),
                            Text(
                              widget.honors.length == 1
                                  ? '1 especialidad'
                                  : '${widget.honors.length} especialidades',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.ink500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Chevron (rotates 90° when open)
                RotationTransition(
                  turns: _chevronAngle,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: c.ink400,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded requirements list
        SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: -1,
          child: Container(
            decoration: BoxDecoration(
              color: c.canvas,
              border: Border(
                top: BorderSide(color: c.ink100, width: 1),
              ),
            ),
            child: module.requirements.isEmpty && widget.honors.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Text(
                      'Sin requerimientos cargados',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.ink400,
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...module.requirements.map((req) {
                        return RequirementCard(
                          requirement: req,
                          onTap: () => widget.onRequirementTap(req),
                        );
                      }),
                      if (widget.honors.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'classes.honors.module_section'.tr(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink500,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...widget.honors.map(
                                (honor) => ClassHonorActionsRow(honor: honor),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
