import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_submission_readiness.dart';

/// Compact row for one top-level requirement: status circle, text, meta chips
/// and a chevron. Tapping opens the requirement sheet.
class HonorRequirementRow extends StatelessWidget {
  const HonorRequirementRow({
    super.key,
    required this.readiness,
    required this.paintColor,
    required this.onTap,
  });

  final RequirementReadiness readiness;

  /// Category paint color (fills the done circle and tints the partial one).
  final Color paintColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;
    final req = readiness.requirement;
    final done = readiness.status == RequirementStatus.done;
    final chips = _chips(context);

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusCircle(
                    key: ValueKey('requirement-status-${req.id}'),
                    status: readiness.status,
                    number: _label(),
                    paintColor: paintColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: done ? c.textSecondary : c.text,
                          ),
                        ),
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 6, children: chips),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: ExcludeSemantics(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        size: 18,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _label() {
    final req = readiness.requirement;
    final label = req.displayLabel;
    return (label != null && label.isNotEmpty)
        ? label
        : '${req.requirementNumber}';
  }

  List<Widget> _chips(BuildContext context) {
    final r = readiness;
    final done = r.status == RequirementStatus.done;
    final chips = <Widget>[];

    if (r.isLeaf) {
      if (r.isSatisfied) {
        chips.add(SacBadge.success(
          label: 'honors.requirements.meta_answered'.tr(),
        ));
      }
      if (r.ownEvidenceCount > 0) {
        chips.add(SacBadge.success(
          label: 'honors.requirements.meta_has_evidence'.tr(),
        ));
      }
    } else {
      final label = r.isChoiceGroup
          ? 'honors.requirements.meta_choose_done'.plural(
              r.childSatisfied,
              namedArgs: {'min': '${r.childRequired}'},
            )
          : 'honors.requirements.meta_children_done'.tr(namedArgs: {
              'done': '${r.childSatisfied}',
              'total': '${r.childTotal}',
            });
      chips.add(
        done
            ? SacBadge.success(label: label)
            : r.childSatisfied > 0
                ? SacBadge.warning(label: label)
                : SacBadge(variant: SacBadgeVariant.neutral, label: label),
      );
    }

    final needsPhoto = r.hasMissingEvidence ||
        (r.requirement.requiresEvidence && r.ownEvidenceCount == 0);
    if (needsPhoto) {
      chips.add(SacBadge(
        variant: SacBadgeVariant.neutral,
        icon: HugeIcons.strokeRoundedCamera01,
        label: 'honors.requirements.meta_missing_photo'.tr(),
      ));
    }
    return chips;
  }
}

class _StatusCircle extends StatelessWidget {
  const _StatusCircle({
    super.key,
    required this.status,
    required this.number,
    required this.paintColor,
  });

  final RequirementStatus status;
  final String number;
  final Color paintColor;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final text = Theme.of(context).textTheme;

    final Color fill;
    final Color border;
    switch (status) {
      case RequirementStatus.done:
        fill = paintColor;
        border = paintColor;
      case RequirementStatus.partial:
        fill = paintColor.withValues(alpha: 0.12);
        border = paintColor;
      case RequirementStatus.todo:
        fill = Colors.transparent;
        border = c.ink300;
    }

    return AnimatedContainer(
      duration: reduce ? Duration.zero : SacMotion.press,
      curve: SacMotion.easeOut,
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 1.5),
      ),
      child: status == RequirementStatus.done
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedTick02,
              size: 15,
              color: onCategoryPaintColor(paintColor, onNearWhite: c.text),
            )
          : Text(
              number,
              maxLines: 1,
              style: text.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: status == RequirementStatus.partial
                    ? c.text
                    : c.textSecondary,
              ),
            ),
    );
  }
}
