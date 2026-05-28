import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../domain/entities/award_tier.dart';

/// Fila-card de ranking de un miembro dentro de su sección.
///
/// Diseño mobile-first: target táctil ≥64dp, jerarquía clara, score visible y
/// sin depender de hover/gestos ocultos.
class MemberRankingListTile extends StatelessWidget {
  final int rankPosition;
  final String memberName;
  final String? sectionName;
  final double? compositeScore;
  final String? awardedCategoryName;
  final AwardTier awardedCategoryTier;
  final VoidCallback? onTap;

  const MemberRankingListTile({
    super.key,
    required this.rankPosition,
    required this.memberName,
    this.sectionName,
    this.compositeScore,
    this.awardedCategoryName,
    this.awardedCategoryTier = AwardTier.unknown,
    this.onTap,
  });

  Color _tierColor(BuildContext context) {
    if (awardedCategoryTier == AwardTier.unknown) {
      return context.sac.textTertiary;
    }
    return awardedCategoryTier.color;
  }

  String _formatScore(double score) {
    return score.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final tierColor = _tierColor(context);
    final hasScore = compositeScore != null;
    final isTop3 = rankPosition <= 3;
    final scoreLabel = hasScore ? _formatScore(compositeScore!) : '—';
    final progressValue =
        hasScore ? (compositeScore! / 100).clamp(0.0, 1.0) : 0.0;

    final semanticsLabel = tr(
      'rankings.section_ranking.member_semantics',
      namedArgs: {
        'position': rankPosition.toString(),
        'name': memberName,
        'score': hasScore
            ? scoreLabel
            : tr('rankings.section_ranking.score_unavailable'),
        'section':
            sectionName ?? tr('rankings.section_ranking.section_unknown'),
      },
    );

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: SacCard(
        onTap: onTap,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        borderColor: isTop3 ? tierColor.withValues(alpha: 0.35) : null,
        backgroundColor: c.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _RankBadge(
                    rankPosition: rankPosition,
                    color: isTop3 ? tierColor : c.border,
                    foreground: isTop3 ? Colors.white : c.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          memberName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.text,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          sectionName ??
                              tr('rankings.section_ranking.section_unknown'),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: c.textSecondary,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ScoreBadge(
                    label: scoreLabel,
                    color: tierColor,
                    hasScore: hasScore,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 7,
                  backgroundColor: c.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hasScore ? tierColor : c.textTertiary,
                  ),
                ),
              ),
              if (awardedCategoryName != null) ...[
                const SizedBox(height: 10),
                _CategoryChip(name: awardedCategoryName!, color: tierColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rankPosition;
  final Color color;
  final Color foreground;

  const _RankBadge({
    required this.rankPosition,
    required this.color,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '#$rankPosition',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool hasScore;

  const _ScoreBadge({
    required this.label,
    required this.color,
    required this.hasScore,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      constraints: const BoxConstraints(minWidth: 58, minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: hasScore ? color.withValues(alpha: 0.12) : c.borderLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasScore ? color.withValues(alpha: 0.35) : c.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: hasScore ? color : c.textSecondary,
                ),
          ),
          Text(
            tr('rankings.section_ranking.score_short'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: c.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String name;
  final Color color;

  const _CategoryChip({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
