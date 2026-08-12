import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_network_image.dart';
import '../../domain/entities/annual_ranking_progress.dart';
import '../utils/ranking_tier_medal_assets.dart';

const double _kMedalSize = 56;

/// Opens a modal bottom sheet listing every recognition tier and its points band.
///
/// Prefer [tiers] from the progress API. If empty (older backend), uses
/// [fallbackTiers] so the sheet still opens with whatever ranges are known.
/// When [currentTier] is null, appends a “Sin rango” row (gray copper medal).
Future<void> showRankingTiersSheet({
  required BuildContext context,
  required List<RankingTier> tiers,
  RankingTier? currentTier,
  List<RankingTier> fallbackTiers = const [],
}) {
  final resolved = _resolveTiersForSheet(tiers, fallbackTiers);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RankingTiersSheet(
      tiers: resolved,
      currentTierSlug: currentTier?.slug,
      hasCurrentTier: currentTier != null &&
          currentTier.name.trim().isNotEmpty,
    ),
  );
}

List<RankingTier> _resolveTiersForSheet(
  List<RankingTier> tiers,
  List<RankingTier> fallbackTiers,
) {
  if (tiers.isNotEmpty) return tiers;
  final seen = <String>{};
  final out = <RankingTier>[];
  for (final tier in fallbackTiers) {
    final key = tier.slug.toLowerCase().trim();
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(tier);
  }
  return out;
}

class _RankingTiersSheet extends StatelessWidget {
  final List<RankingTier> tiers;
  final String? currentTierSlug;
  final bool hasCurrentTier;

  const _RankingTiersSheet({
    required this.tiers,
    required this.currentTierSlug,
    required this.hasCurrentTier,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final ordered = [...tiers]
      ..sort((a, b) => b.fromPoints.compareTo(a.fromPoints));
    final showNoTierRow = ordered.isNotEmpty;
    final itemCount = ordered.length + (showNoTierRow ? 1 : 0);
    final noTierCeiling = ordered.isEmpty
        ? 0
        : ordered.map((t) => t.fromPoints).reduce((a, b) => a < b ? a : b);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('rankings.annual_progress.tiers_sheet.title'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('rankings.annual_progress.tiers_sheet.subtitle'),
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ordered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: Text(
                      tr('rankings.annual_progress.tiers_sheet.empty'),
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: itemCount,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index < ordered.length) {
                        final tier = ordered[index];
                        final isCurrent = hasCurrentTier &&
                            currentTierSlug != null &&
                            tier.slug.toLowerCase() ==
                                currentTierSlug!.toLowerCase();
                        return _TierRow(
                          name: tier.name,
                          rangeLabel: tr(
                            'rankings.annual_progress.tiers_sheet.range',
                            namedArgs: {
                              'from': _formatPoints(tier.fromPoints),
                              'to': _formatPoints(tier.toPoints),
                            },
                          ),
                          medalUrl: rankingTierRemoteMedalUrl(tier.slug) ??
                              tier.imageUrl,
                          isCurrent: isCurrent,
                          grayscale: false,
                        );
                      }

                      // “Sin rango” — below lowest configured band.
                      final toPoints = (noTierCeiling - 1).clamp(0, noTierCeiling);
                      return _TierRow(
                        name: tr(
                          'rankings.annual_progress.tiers_sheet.no_tier_name',
                        ),
                        rangeLabel: tr(
                          'rankings.annual_progress.tiers_sheet.no_tier_range',
                          namedArgs: {
                            'to': _formatPoints(toPoints),
                          },
                        ),
                        // copper.png no existe en R2 — usar bronce en escala de grises.
                        medalUrl: rankingTierRemoteMedalUrl('bronze'),
                        isCurrent: !hasCurrentTier,
                        grayscale: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final String name;
  final String rangeLabel;
  final String? medalUrl;
  final bool isCurrent;
  final bool grayscale;

  const _TierRow({
    required this.name,
    required this.rangeLabel,
    required this.medalUrl,
    required this.isCurrent,
    required this.grayscale,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.08)
            : c.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary.withValues(alpha: 0.35)
              : c.border.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          _MedalThumb(
            imageUrl: medalUrl,
            size: _kMedalSize,
            grayscale: grayscale,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rangeLabel,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            const _CurrentTierBadge(),
          ],
        ],
      ),
    );
  }
}

class _CurrentTierBadge extends StatelessWidget {
  const _CurrentTierBadge();

  @override
  Widget build(BuildContext context) {
    // ~20% smaller than the previous 11.5 / 10×4 badge.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        tr('rankings.annual_progress.tiers_sheet.current_badge'),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 9.2,
          fontWeight: FontWeight.w800,
          height: 1.2,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _MedalThumb extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final bool grayscale;

  const _MedalThumb({
    required this.imageUrl,
    required this.size,
    this.grayscale = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.surfaceVariant,
        ),
      );
    }

    Widget image = SacNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      memCacheWidth: (size * 3).round().clamp(96, 1024),
      errorWidget: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.surfaceVariant,
        ),
      ),
    );

    if (grayscale) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: image,
      );
    }

    return SizedBox(width: size, height: size, child: image);
  }
}

String _formatPoints(int points) =>
    NumberFormat.decimalPattern().format(points);
