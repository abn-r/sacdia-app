import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_expansion_tile.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';

import '../../domain/entities/class_module.dart';
import '../../domain/entities/class_section.dart';
import '../../domain/entities/requirement_track.dart';
import 'class_honor_actions.dart';
import 'section_checkbox.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

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
        child: SacExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          leading: AnimatedContainer(
            duration: SacMotion.reduceMotionOf(context)
                ? SacMotion.reducedFade
                : SacMotion.standard,
            curve: SacMotion.easeOut,
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isComplete
                  ? context.sac.successContainer
                  : SacAccent.of(context).light,
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
            child: SacStateSwap(
              duration: SacMotion.standard,
              child: isComplete
                  ? HugeIcon(
                      key: const ValueKey('module-badge-done'),
                      icon: HugeIcons.strokeRoundedTick02,
                      size: 20,
                      color: context.sac.onSuccessContainer,
                    )
                  : Text(
                      '$completedCount/$totalCount',
                      key: ValueKey('module-badge-$completedCount-$totalCount'),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        fontWeight: FontWeight.w700,
                        color: SacAccent.of(context).color,
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
            child: SacTweenedBar(
              value: progress,
              minHeight: 4,
              backgroundColor: context.sac.borderLight,
              color: isComplete
                  ? AppColors.secondary
                  : SacAccent.of(context).color,
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
                      fontSize: SacFontSize.labelSmall,
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
        label: RequirementTrackMeta.labelKey(track).tr(),
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
    final subtitle =
        isAdvanced ? 'classes.detail_with_progress.track_advanced'.tr() : null;
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 8, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                color: c.ink500,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: SacFontSize.caption,
                color: c.ink400,
              ),
            ),
        ],
      ),
    );
  }
}
