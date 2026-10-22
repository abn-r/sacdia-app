import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/instructor_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/evidence_age.dart';

/// Card of a pending evidence in the review queue.
///
/// Member, what was submitted (context and club section) and a footer with how
/// long it has been waiting, its type and the number of attached files.
class EvidenceReviewCard extends StatelessWidget {
  const EvidenceReviewCard({
    super.key,
    required this.item,
    required this.onTap,
    this.animate = false,
    this.animationDelay = Duration.zero,
  });

  final EvidenceReviewItem item;
  final VoidCallback onTap;
  final bool animate;
  final Duration animationDelay;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final deleted = item.memberIsDeleted;
    final contextLine = item.context?.trim() ?? '';
    final clubLine = item.clubSectionLabel?.trim() ?? '';

    return SacCard(
      onTap: onTap,
      animate: animate,
      animationDelay: animationDelay,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InstructorAvatar(
            name: deleted ? '?' : item.memberName,
            photoUrl: deleted ? null : item.memberPhotoUrl,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayMemberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: deleted ? c.textTertiary : c.text,
                    fontStyle: deleted ? FontStyle.italic : null,
                  ),
                ),
                if (contextLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    contextLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
                if (clubLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    clubLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EvidenceAgeBadge(age: EvidenceAge.of(item.submittedAt)),
                    SacBadge(
                      variant: SacBadgeVariant.neutral,
                      label: item.type.displayLabel,
                    ),
                    _AttachmentCount(count: item.fileCount),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 18,
              color: c.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentCount extends StatelessWidget {
  const _AttachmentCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final label = (count == 1
            ? 'coordinator.evidence_review.card.files_one'
            : 'coordinator.evidence_review.card.files_other')
        .tr(namedArgs: {'count': '$count'});

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedAttachment01,
          size: 14,
          color: c.textTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: c.textTertiary),
        ),
      ],
    );
  }
}
