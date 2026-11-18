import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../domain/entities/annual_ranking_progress.dart';
import '../utils/annual_progress_math.dart';
import 'annual_progress_parts.dart';

/// Sheet with every tier the API reports: medal, name, "Desde N pts" and the
/// reached check or the current marker.
Future<void> showAnnualTiersSheet(
  BuildContext context, {
  required AnnualRankingProgress progress,
}) {
  return showSacSheet<void>(
    context: context,
    builder: (_) => AnnualTiersSheet(progress: progress),
  );
}

class AnnualTiersSheet extends StatelessWidget {
  const AnnualTiersSheet({super.key, required this.progress});

  final AnnualRankingProgress progress;

  @override
  Widget build(BuildContext context) {
    final tiers = annualKnownTiers(progress);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(
            title: tr('rankings.annual_progress.tiers_sheet.title'),
            showClose: true,
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: tiers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) => AnnualTierRow(
                tier: tiers[index],
                isReached: progress.currentPoints >= tiers[index].fromPoints,
                isCurrent: progress.currentTier?.slug == tiers[index].slug,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnnualTierRow extends StatelessWidget {
  const AnnualTierRow({
    super.key,
    required this.tier,
    required this.isReached,
    required this.isCurrent,
  });

  final RankingTier tier;
  final bool isReached;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final locale = annualLocaleOf(context);
    final name = tier.name.trim();
    final from = tr(
      'rankings.annual_progress.tiers_sheet.from_points',
      namedArgs: {'points': formatAnnualPoints(tier.fromPoints, locale)},
    );
    final state = isCurrent
        ? tr('rankings.annual_progress.tiers_sheet.current')
        : isReached
            ? tr('rankings.annual_progress.tiers_sheet.reached')
            : null;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: [name, from, if (state != null) state].join(', '),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              AnnualTierMedal(tier: tier, size: 48, unearned: !isReached),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isReached ? c.text : c.textSecondary,
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      from,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: SacFontSize.bodyMedium,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                _CurrentMarker(
                  label: tr('rankings.annual_progress.tiers_sheet.current'),
                )
              else if (isReached)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  size: 22,
                  color: c.success,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentMarker extends StatelessWidget {
  const _CurrentMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: 14,
            color: c.success,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: c.success,
              fontSize: SacFontSize.bodySmall,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
