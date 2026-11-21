import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_presentation.dart';

/// Requirements of a mastery in the detail sheet.
///
/// One group: a single card with the category, "3 de 7 especialidades", a
/// bar in the app accent and the honors that already count. Several groups:
/// the eyebrow "Requisitos · 0 de 2" and one row per group with its own
/// count. The bar turns to the warning colour only when the mastery is no
/// longer valid.
class MasterHonorRequirementsSection extends StatelessWidget {
  const MasterHonorRequirementsSection({
    super.key,
    required this.item,
    required this.isLapsed,
  });

  final MasterHonorRoadmap item;
  final bool isLapsed;

  @override
  Widget build(BuildContext context) {
    final groups = item.requirementGroups;

    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Text(
          'master_honors.detail.no_requirements'.tr(),
          style: TextStyle(
            fontSize: SacFontSize.bodyMedium,
            color: context.sac.textTertiary,
          ),
        ),
      );
    }

    if (groups.length == 1) {
      return _SingleRequirement(group: groups.first, isLapsed: isLapsed);
    }

    return SacGroupedSection(
      label: 'master_honors.detail.requirements_progress'.tr(
        namedArgs: {
          'done': '${masterHonorPassedGroups(item)}',
          'total': '${groups.length}',
        },
      ),
      action: const SizedBox.shrink(),
      children: [for (final group in groups) _RequirementRow(group: group)],
    );
  }
}

class _SingleRequirement extends StatelessWidget {
  const _SingleRequirement({required this.group, required this.isLapsed});

  final MasterHonorRoadmapGroup group;
  final bool isLapsed;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final required = group.minimumRequired;
    final fraction =
        required <= 0 ? 0.0 : (group.currentCount / required).clamp(0.0, 1.0);
    final barColor =
        isLapsed ? c.onWarningContainer : SacAccent.of(context).color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'master_honors.detail.requirement_title'.tr().toUpperCase(),
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: c.textTertiary,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: c.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    masterHonorRequirementLabel(group),
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    masterHonorSpecialtiesCount(group),
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                  if (masterHonorShowsRequirementDescription(group)) ...[
                    const SizedBox(height: 6),
                    Text(
                      group.description!.trim(),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.35,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SacTweenedBar(
                    value: fraction,
                    color: barColor,
                    backgroundColor: c.border,
                    minHeight: 6,
                    borderRadius: AppTheme.radiusHairline * 1.5,
                  ),
                  _HonorChips(group: group),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chips of the honors that count for a group: the matched honors of a
/// category group (names come from the honors catalog) or the options of an
/// explicit group (done ones highlighted).
class _HonorChips extends StatelessWidget {
  const _HonorChips({required this.group});

  final MasterHonorRoadmapGroup group;

  @override
  Widget build(BuildContext context) {
    if (group.options.isNotEmpty) {
      return _ChipWrap(
        chips: [
          for (final option in group.options)
            _ChipData(label: option.label, done: option.completed),
        ],
      );
    }
    if (group.matchedHonorIds.isEmpty) return const SizedBox.shrink();
    return _MatchedHonorChips(ids: group.matchedHonorIds);
  }
}

class _MatchedHonorChips extends ConsumerWidget {
  const _MatchedHonorChips({required this.ids});

  final List<int> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honors = ref.watch(allHonorsProvider).value;
    if (honors == null) return const SizedBox.shrink();

    final names = {for (final honor in honors) honor.id: honor.name};
    return _ChipWrap(
      chips: [
        for (final id in ids)
          if (names[id] != null) _ChipData(label: names[id]!, done: true),
      ],
    );
  }
}

class _ChipData {
  const _ChipData({required this.label, required this.done});

  final String label;
  final bool done;
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.chips});

  final List<_ChipData> chips;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final chip in chips)
            DecoratedBox(
              decoration: BoxDecoration(
                color: chip.done ? c.successContainer : c.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  chip.label,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    fontWeight: FontWeight.w600,
                    color: chip.done ? c.onSuccessContainer : c.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row of the multi-group list: status tile, requirement name and its
/// own count (or, for "choose N of M", the options on one line).
class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.group});

  final MasterHonorRoadmapGroup group;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isOptions = group.options.isNotEmpty;
    final hasTitle = (group.title?.trim().isNotEmpty ?? false) ||
        (group.categoryName?.trim().isNotEmpty ?? false);
    final choose = 'master_honors.detail.choose_of'.tr(
      namedArgs: {
        'min': '${group.minimumRequired}',
        'total': '${group.options.length}',
      },
    );

    final title =
        isOptions && !hasTitle ? choose : masterHonorRequirementLabel(group);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: group.passed ? c.successContainer : c.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
            child: SizedBox.square(
              dimension: 32,
              child: Center(
                child: HugeIcon(
                  icon: group.passed
                      ? HugeIcons.strokeRoundedTick02
                      : HugeIcons.strokeRoundedCircle,
                  size: 16,
                  color: group.passed ? c.onSuccessContainer : c.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: SacFontSize.titleSmall,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                if (!isOptions)
                  Text(
                    masterHonorSpecialtiesCount(group),
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  )
                else ...[
                  if (hasTitle)
                    Text(
                      choose,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  _OptionsLine(options: group.options),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The options of a "choose N of M" group on one wrapped line, the done ones
/// in the success colour.
class _OptionsLine extends StatelessWidget {
  const _OptionsLine({required this.options});

  final List<MasterHonorRoadmapOption> options;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final base = TextStyle(
      fontSize: SacFontSize.bodySmall,
      height: 1.35,
      color: c.textSecondary,
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const TextSpan(text: ' · '),
            TextSpan(
              text: options[i].label,
              style: options[i].completed
                  ? base.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.onSuccessContainer,
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
