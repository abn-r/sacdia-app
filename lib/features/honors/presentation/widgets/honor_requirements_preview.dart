import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';

/// "Requisitos" tab of an honor the member has not joined yet: the top-level
/// requirements of the catalog as a read-only compact list.
///
/// Each row is a neutral numbered circle and the text; a requirement with
/// sub-items adds a count chip and a choice group says "Elige N de M". A
/// caption under the card explains that the work mode is picked on joining.
/// Loading shows skeleton rows and a failure shows an inline error with retry.
class HonorRequirementsPreview extends StatelessWidget {
  const HonorRequirementsPreview({
    super.key,
    required this.requirements,
    required this.onRetry,
  });

  final AsyncValue<List<HonorRequirement>> requirements;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.sac;

    // Keep the list while a reload runs; only a first load shows skeletons.
    final items = requirements.value;
    final Widget body;
    if (items != null) {
      body = items.isEmpty
          ? SacEmptyState.inline(title: 'honors.requirements.empty'.tr())
          : _Rows(items: items);
    } else if (requirements.hasError) {
      body = SacErrorState.inline(
        message: userErrorMessage(requirements.error),
        onRetry: onRetry,
      );
    } else {
      body = const _RowsSkeleton();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: body,
        ),
        const SizedBox(height: 12),
        Text(
          'honors.catalog.enroll_hint'.tr(),
          key: const ValueKey('requirements-preview-caption'),
          style: text.bodySmall?.copyWith(color: c.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.items});

  final List<HonorRequirement> items;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final ordered = [...items]
      ..sort((a, b) => a.requirementNumber.compareTo(b.requirementNumber));
    return Column(
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: c.borderLight),
          _Row(
            key: ValueKey('requirement-preview-${ordered[i].id}'),
            requirement: ordered[i],
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.requirement});

  final HonorRequirement requirement;

  String _number() {
    final label = requirement.displayLabel;
    return (label != null && label.isNotEmpty)
        ? label
        : '${requirement.requirementNumber}';
  }

  String? _chipLabel() {
    final children = requirement.children.length;
    if (children == 0) return null;
    if (requirement.isChoiceGroup) {
      final min = (requirement.choiceMin ?? 1).clamp(0, children);
      return 'honors.catalog.choose_n_of_m'
          .tr(namedArgs: {'min': '$min', 'total': '$children'});
    }
    return 'honors.catalog.sub_items'.plural(children);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;
    final chip = _chipLabel();

    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surfaceVariant,
                ),
                child: Text(
                  _number(),
                  maxLines: 1,
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requirement.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: c.text,
                      ),
                    ),
                    if (chip != null) ...[
                      const SizedBox(height: 6),
                      SacBadge(variant: SacBadgeVariant.neutral, label: chip),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowsSkeleton extends StatelessWidget {
  const _RowsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SacSkeletonList(
      itemCount: 4,
      scrollable: false,
      padding: EdgeInsets.symmetric(vertical: 12),
    );
  }
}
