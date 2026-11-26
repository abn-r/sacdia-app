import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_summary_box.dart';
import 'package:sacdia_app/features/rankings/domain/entities/annual_ranking_progress.dart';
import 'package:sacdia_app/features/rankings/presentation/widgets/annual_progress_parts.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_annual_progress.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';

/// The medals of the annual progress, by tier.
enum SupervisionTierKind { diamond, gold, silver, bronze, none }

/// Tier of a club from the name or slug the server sends («Oro», `gold`).
/// A club with no tier is [SupervisionTierKind.none]; a tier this app does not
/// know reads as bronze, like the club-side medal color does.
SupervisionTierKind supervisionTierKind(SupervisionProgressTier? tier) {
  if (tier == null) return SupervisionTierKind.none;
  final key = '${tier.slug} ${tier.name}'.toLowerCase();
  if (key.trim().isEmpty) return SupervisionTierKind.none;
  if (key.contains('diamond') || key.contains('diamante')) {
    return SupervisionTierKind.diamond;
  }
  if (key.contains('gold') || key.contains('oro')) {
    return SupervisionTierKind.gold;
  }
  if (key.contains('silver') || key.contains('plata')) {
    return SupervisionTierKind.silver;
  }
  return SupervisionTierKind.bronze;
}

/// Tier as the club-side medal widgets read it.
RankingTier supervisionRankingTier(SupervisionProgressTier tier) => RankingTier(
      name: tier.name,
      slug: tier.slug,
      fromPoints: tier.fromPoints.round(),
      toPoints: tier.toPoints.round(),
    );

RankingTier _tierOfKind(SupervisionTierKind kind) {
  final slug = switch (kind) {
    SupervisionTierKind.diamond => 'diamond',
    SupervisionTierKind.gold => 'gold',
    SupervisionTierKind.silver => 'silver',
    SupervisionTierKind.bronze || SupervisionTierKind.none => 'bronze',
  };
  return RankingTier(name: slug, slug: slug, fromPoints: 0, toPoints: 0);
}

/// Color of a tier (the club-side medal colors); grey for no medal.
Color supervisionTierColor(BuildContext context, SupervisionTierKind kind) {
  if (kind == SupervisionTierKind.none) {
    return context.sac.textTertiary.withValues(alpha: 0.45);
  }
  return annualTierColor(context, _tierOfKind(kind));
}

String supervisionTierLabel(SupervisionTierKind kind) => switch (kind) {
      SupervisionTierKind.diamond => 'supervision.annual_progress.tier_diamond',
      SupervisionTierKind.gold => 'supervision.annual_progress.tier_gold',
      SupervisionTierKind.silver => 'supervision.annual_progress.tier_silver',
      SupervisionTierKind.bronze => 'supervision.annual_progress.tier_bronze',
      SupervisionTierKind.none => 'supervision.annual_progress.tier_none',
    }
        .tr();

/// Medal of a tier at [size]. With no medal yet: the bronze one, grey.
class SupervisionTierMedal extends StatelessWidget {
  const SupervisionTierMedal({super.key, required this.tier, this.size = 36});

  final SupervisionProgressTier? tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final kind = supervisionTierKind(tier);
    // Decorative: the row says the tier in text.
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: AnnualTierMedal(
          tier: tier == null || kind == SupervisionTierKind.none
              ? _tierOfKind(SupervisionTierKind.bronze)
              : supervisionRankingTier(tier!),
          size: size,
          unearned: kind == SupervisionTierKind.none,
        ),
      ),
    );
  }
}

// ── «Medallas en el campo» ──────────────────────────────────────────────────

/// How many clubs hold each medal: a bar by tier and its legend. Counts the
/// clubs of the list on screen; no positions, no order.
class SupervisionTierBox extends StatelessWidget {
  const SupervisionTierBox({super.key, required this.clubs});

  final List<SupervisionClubProgress> clubs;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final counts = {for (final kind in SupervisionTierKind.values) kind: 0};
    for (final club in clubs) {
      final kind = supervisionTierKind(club.currentTier);
      counts[kind] = counts[kind]! + 1;
    }
    final total = clubs.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SacSummaryBox(
        color: c.surfaceVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'supervision.annual_progress.medals_title'.tr(),
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  (total == 1
                          ? 'supervision.annual_progress.clubs_count_one'
                          : 'supervision.annual_progress.clubs_count')
                      .tr(args: [supervisionCount(context, total)]),
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SacStatusBar(
              segments: [
                for (final kind in SupervisionTierKind.values)
                  SacStatusSegment(
                    count: counts[kind]!,
                    color: supervisionTierColor(context, kind),
                    label:
                        '${supervisionTierLabel(kind)} ${supervisionCount(context, counts[kind]!)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── A club of the list ──────────────────────────────────────────────────────

/// Medal of the current tier, club name, «Oro · 8,720 pts», the percent and a
/// thin bar in the tier color. Never a position.
class SupervisionClubProgressRow extends StatelessWidget {
  const SupervisionClubProgressRow({
    super.key,
    required this.club,
    required this.onTap,
  });

  final SupervisionClubProgress club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final kind = supervisionTierKind(club.currentTier);
    final tierName = club.currentTier?.name.trim() ?? '';
    final color = supervisionTierColor(context, kind);
    final points = 'supervision.annual_progress.points_short'
        .tr(args: [supervisionPoints(context, club.currentPoints)]);
    return SacListRow(
      leading: SupervisionTierMedal(tier: club.currentTier),
      title: club.clubName,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                if (tierName.isNotEmpty) ...[
                  TextSpan(
                    text: tierName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const TextSpan(text: ' · '),
                ],
                TextSpan(text: points),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              height: 1.3,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          _Bar(fraction: club.progressPercentage / 100, color: color),
        ],
      ),
      trailing: Text(
        supervisionPercent(club.progressPercentage),
        maxLines: 1,
        style: TextStyle(
          fontSize: SacFontSize.titleMedium,
          fontWeight: FontWeight.w600,
          color: c.text,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onTap: onTap,
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SacTweenedBar(
        value: fraction,
        color: color,
        backgroundColor: annualTrackColor(context.sac),
      ),
    );
  }
}

/// Progress bar of a component, in the color of its axis.
class SupervisionAxisBar extends StatelessWidget {
  const SupervisionAxisBar({
    super.key,
    required this.fraction,
    required this.color,
  });

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => _Bar(fraction: fraction, color: color);
}

// ── Union / local field pickers ─────────────────────────────────────────────

/// A union or local field: tinted building icon, name and what the server
/// says about it («8 clubes · 3 con Oro o más», or «Sin configurar» in
/// warning). With names only (an older server) there is no second line.
///
/// The gold count shows only when the server computed it (never a null read
/// as 0), the territory has clubs and it is configured: without an annual
/// configuration no club can hold a medal, so the number would say nothing.
class SupervisionTerritoryRow extends StatelessWidget {
  const SupervisionTerritoryRow({
    super.key,
    required this.option,
    required this.onTap,
  });

  final SupervisionTerritoryOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final count = option.clubsCount;
    final unconfigured = option.configured == false;
    final warning = SacTonePalette.of(context, SacTone.warning).onContainer;
    final countText = count == null
        ? null
        : (count == 1
                ? 'supervision.annual_progress.clubs_count_one'
                : 'supervision.annual_progress.clubs_count')
            .tr(args: [supervisionCount(context, count)]);
    final gold = option.goldOrBetterCount;
    final goldText = gold == null || unconfigured || count == null || count == 0
        ? null
        : 'supervision.annual_progress.gold_or_better'
            .tr(args: [supervisionCount(context, gold)]);
    final style = TextStyle(
      fontSize: SacFontSize.bodyMedium,
      height: 1.3,
      color: c.textSecondary,
    );
    return SacListRow(
      leading: SacListRowIcon(
        HugeIcons.strokeRoundedBuilding01,
        tone: unconfigured ? SacTone.warning : SacTone.accent,
      ),
      title: option.name,
      subtitleWidget: countText == null && !unconfigured
          ? null
          : Text.rich(
              TextSpan(
                children: [
                  if (countText != null) TextSpan(text: countText),
                  if (goldText != null) TextSpan(text: ' · $goldText'),
                  if (countText != null && unconfigured)
                    const TextSpan(text: ' · '),
                  if (unconfigured)
                    TextSpan(
                      text: 'supervision.annual_progress.unconfigured'.tr(),
                      style: TextStyle(
                        color: warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
      onTap: onTap,
    );
  }
}
