import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_submission_readiness.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_band_scaffold.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_requirement_evidence.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_requirement_row.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_requirement_sheet.dart';

/// Label of a requirement as the member reads it: its display label ("c",
/// "4.1") or its number.
String honorRequirementLabel(HonorRequirement requirement) {
  final label = requirement.displayLabel?.trim();
  return label != null && label.isNotEmpty
      ? label
      : '${requirement.requirementNumber}';
}

/// How many children satisfy [requirement]: `max(choice_min ?? 1, 0)` for a
/// choice group (backend L569), all of them otherwise.
int honorRequiredChildren(HonorRequirement requirement) {
  if (!requirement.isChoiceGroup) return requirement.children.length;
  final minimum = requirement.choiceMin ?? 1;
  return minimum < 0 ? 0 : minimum;
}

/// Opens [requirement] the way it is worked: a requirement with sub-items
/// gets its own screen ([HonorRequirementGroupView]); any other one opens
/// the focused [HonorRequirementSheet].
///
/// [parent] is the requirement it sits under (null for a top-level one) and
/// [root] the top-level requirement of the branch.
Future<void> openHonorRequirement(
  BuildContext context, {
  required int honorId,
  required String honorName,
  required HonorRequirement requirement,
  required Color paintColor,
  required Color bandColor,
  required bool enabled,
  HonorRequirement? parent,
  HonorRequirement? root,
}) {
  final label = honorRequirementLabel(requirement);
  final title = parent == null
      ? 'honors.requirements.sheet_title'.tr(namedArgs: {'number': label})
      : 'honors.requirements.sub_title'.tr(namedArgs: {'label': label});

  if (requirement.children.isNotEmpty) {
    return Navigator.of(context).push(
      SacSharedAxisRoute<void>(
        builder: (_) => HonorRequirementGroupView(
          honorId: honorId,
          honorName: honorName,
          requirement: requirement,
          title: title,
          root: root ?? requirement,
          paintColor: paintColor,
          bandColor: bandColor,
          enabled: enabled,
        ),
      ),
    );
  }

  String? contextLine;
  if (parent != null) {
    final parentLabel = honorRequirementLabel(parent);
    contextLine = parent.isChoiceGroup
        ? 'honors.requirements.group_context_choice'.tr(namedArgs: {
            'number': parentLabel,
            'min': '${honorRequiredChildren(parent)}',
            'total': '${parent.children.length}',
          })
        : 'honors.requirements.group_context'
            .tr(namedArgs: {'number': parentLabel});
  }

  return HonorRequirementSheet.show(
    context,
    honorId: honorId,
    requirement: requirement,
    title: title,
    contextLine: contextLine,
    root: root,
    paintColor: paintColor,
    bandColor: bandColor,
    enabled: enabled,
  );
}

/// Screen of a requirement with sub-items (4.1, 4.2… or a, b, c…).
///
/// A compact band names the requirement; the body shows the goal ("Elige 3 ·
/// 2 hechos" for a choice group, "2 de 4 hechos" otherwise), the sub-items
/// with their status (each opens the focused sheet, or its own screen when
/// it has sub-items too), the requirement's own evidence when it asks for it
/// and its folded reference. Statuses follow the stored progress live.
class HonorRequirementGroupView extends ConsumerStatefulWidget {
  const HonorRequirementGroupView({
    super.key,
    required this.honorId,
    required this.honorName,
    required this.requirement,
    required this.title,
    required this.root,
    required this.paintColor,
    required this.bandColor,
    required this.enabled,
  });

  final int honorId;
  final String honorName;
  final HonorRequirement requirement;

  /// "Requisito 4", "Inciso b".
  final String title;

  /// Top-level requirement of the branch (this one when it is top-level).
  final HonorRequirement root;
  final Color paintColor;
  final Color bandColor;
  final bool enabled;

  @override
  ConsumerState<HonorRequirementGroupView> createState() =>
      _HonorRequirementGroupViewState();
}

class _HonorRequirementGroupViewState
    extends ConsumerState<HonorRequirementGroupView> {
  // The bar title ("Requisito 4") takes over once the band's eyebrow line
  // scrolls under it.
  final HonorBandBarController _bar = HonorBandBarController(titleOffset: 24);
  bool _textExpanded = false;
  bool _referenceOpen = false;

  @override
  void initState() {
    super.initState();
    _bar.scroll.addListener(() => _bar.update(SacTopBar.frostedInset(context)));
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  Future<void> _syncParents() async {
    final progress =
        await ref.read(userHonorProgressProvider(widget.honorId).future);
    final updates =
        evidenceParentUpdates(roots: [widget.root], progress: progress);
    if (updates.isEmpty) return;
    await ref
        .read(requirementProgressNotifierProvider(widget.honorId).notifier)
        .bulkUpdate(updates);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final req = widget.requirement;
    final progress =
        ref.watch(userHonorProgressProvider(widget.honorId)).value ??
            const <UserHonorRequirementProgress>[];
    final readiness = computeHonorSubmissionReadiness(
      requirements: req.children,
      progress: progress,
      completedAt: null,
      mode: HonorCompletionMode.inApp,
      requireCompletionDate: false,
    );
    final required = honorRequiredChildren(req);
    final done = readiness.items.where((i) => i.isSatisfied).length;
    // Answered is not finished while a photo is missing: green only then.
    final complete = done >= required &&
        readiness.items
            .where((i) => i.isSatisfied)
            .every((i) => i.status == RequirementStatus.done);
    UserHonorRequirementProgress? ownRow;
    for (final p in progress) {
      if (p.requirementId == req.id) ownRow = p;
    }
    final reference = req.referenceText?.trim() ?? '';

    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: HonorBandTopBar(controller: _bar, title: widget.title),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _bar.scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Band color above the band, so an overscroll pull shows
                    // the band, not the page.
                    Positioned(
                      top: -screenHeight,
                      left: 0,
                      right: 0,
                      height: screenHeight,
                      child: ColoredBox(color: widget.bandColor),
                    ),
                    KeyedSubtree(key: _bar.bandKey, child: _header(context)),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList.list(
                  children: [
                    _GoalCard(
                      choice: req.isChoiceGroup,
                      done: done,
                      required: required,
                      total: req.children.length,
                      complete: complete,
                      color: widget.bandColor,
                    ),
                    const SizedBox(height: 12),
                    SacCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < readiness.items.length; i++) ...[
                            if (i > 0)
                              Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: c.borderLight),
                            HonorRequirementRow(
                              key: ValueKey(
                                'requirement-row-'
                                '${readiness.items[i].requirement.id}',
                              ),
                              readiness: readiness.items[i],
                              paintColor: widget.paintColor,
                              onTap: () => openHonorRequirement(
                                context,
                                honorId: widget.honorId,
                                honorName: widget.honorName,
                                requirement: readiness.items[i].requirement,
                                parent: req,
                                root: widget.root,
                                paintColor: widget.paintColor,
                                bandColor: widget.bandColor,
                                enabled: widget.enabled,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (req.requiresEvidence) ...[
                      const SizedBox(height: 12),
                      SacCard(
                        child: HonorRequirementEvidence(
                          honorId: widget.honorId,
                          requirementId: req.id,
                          evidences: ownRow?.evidences ?? const [],
                          paintColor: widget.paintColor,
                          enabled: widget.enabled,
                          caption: 'honors.requirements.parent_evidence_caption'
                              .tr(),
                          onChanged: _syncParents,
                        ),
                      ),
                    ],
                    if (reference.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      HonorReferenceCard(
                        text: reference,
                        open: _referenceOpen,
                        onToggle: () =>
                            setState(() => _referenceOpen = !_referenceOpen),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          HonorBandVeil(controller: _bar, bandColor: widget.bandColor),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final req = widget.requirement;
    final white85 = Colors.white.withValues(alpha: 0.85);
    final longText = req.text.length > 120;
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.standard;

    return Container(
      key: const ValueKey('requirement-group-header'),
      color: widget.bandColor,
      padding: EdgeInsets.fromLTRB(
        8,
        SacTopBar.frostedInset(context) + 4,
        20,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.title} · ${widget.honorName}'.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.labelSmall,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: white85,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: longText
                      ? () => setState(() => _textExpanded = !_textExpanded)
                      : null,
                  child: AnimatedSize(
                    duration: duration,
                    curve: SacMotion.easeOut,
                    alignment: Alignment.topLeft,
                    child: Text(
                      req.text,
                      key: const ValueKey('requirement-group-text'),
                      maxLines: !longText || _textExpanded ? null : 3,
                      overflow: !longText || _textExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: SacFontSize.headlineSmall,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (longText)
                  GestureDetector(
                    onTap: () => setState(() => _textExpanded = !_textExpanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _textExpanded
                            ? 'honors.requirements.see_less'.tr()
                            : 'honors.requirements.see_more'.tr(),
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          fontWeight: FontWeight.w600,
                          color: white85,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Elige 3 · 2 hechos" (or "2 de 4 hechos") with a bar toward the goal.
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.choice,
    required this.done,
    required this.required,
    required this.total,
    required this.complete,
    required this.color,
  });

  final bool choice;
  final int done;
  final int required;
  final int total;

  /// Goal reached with no evidence missing.
  final bool complete;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final ink = isDark ? c.text : color;
    final value = required == 0 ? 1.0 : (done / required).clamp(0.0, 1.0);
    final label = choice
        ? 'honors.requirements.group_goal_choice'.tr(namedArgs: {
            'min': '$required',
            'total': '$total',
            'done': '$done',
          })
        : 'honors.requirements.group_goal_all'
            .tr(namedArgs: {'done': '$done', 'total': '$total'});
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.modal;

    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('requirement-group-goal'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.24 : 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusHairline),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: ink.withValues(alpha: 0.18)),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: value),
                      duration: duration,
                      curve: SacMotion.easeOut,
                      builder: (context, v, _) => FractionallySizedBox(
                        widthFactor: v,
                        heightFactor: 1,
                        child: ColoredBox(
                          color: complete ? c.success : ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
