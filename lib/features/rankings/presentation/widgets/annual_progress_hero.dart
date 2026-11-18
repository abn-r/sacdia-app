import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/status_progress/sac_grouped_section.dart';
import '../../domain/entities/annual_ranking_progress.dart';
import '../utils/annual_progress_math.dart';
import 'annual_progress_parts.dart';
import 'annual_tiers_sheet.dart';

/// Medal size of the hero.
const double kAnnualHeroMedalSize = 158;

/// "La medalla que se llena": the next medal, gray, with the same medal in
/// full color filling from the bottom up to the progress made toward it.
class AnnualProgressHero extends StatelessWidget {
  const AnnualProgressHero({
    super.key,
    required this.progress,
    required this.yearName,
  });

  final AnnualRankingProgress progress;
  final String yearName;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final locale = annualLocaleOf(context);
    final current = progress.currentTier;
    final next = progress.nextTier;
    final showcase = next ?? current;
    final hasShowcase = showcase != null;
    final fraction = medalFillFraction(progress);
    final missing = pointsToNextTier(progress);
    final points = formatAnnualPoints(progress.currentPoints, locale);

    final clubLine = tr(
      'rankings.annual_progress.header_body',
      namedArgs: {
        'club': progress.clubName,
        'type': progress.clubType.name,
        'year': yearName,
      },
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            children: [
              Text(
                clubLine,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              if (hasShowcase)
                AnnualMedalFill(
                  tier: showcase,
                  fraction: fraction,
                  pointsLabel: points,
                  semanticsLabel: next == null
                      ? tr(
                          'rankings.annual_progress.medal_semantics_full',
                          namedArgs: {'tier': showcase.name.trim()},
                        )
                      : tr(
                          'rankings.annual_progress.medal_semantics',
                          namedArgs: {
                            'tier': showcase.name.trim(),
                            'percent': (fraction * 100).round().toString(),
                          },
                        ),
                )
              else
                _PointsOnly(points: points),
              if (hasShowcase) ...[
                const SizedBox(height: 16),
                Text(
                  (next == null
                          ? tr('rankings.annual_progress.current_medal')
                          : tr('rankings.annual_progress.next_medal'))
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: SacFontSize.labelSmall,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: c.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  showcase.name.trim(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.text,
                    fontSize: SacFontSize.displayMedium,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                if (next != null && missing != null)
                  AnnualEmphasisText(
                    text: tr(
                      'rankings.annual_progress.points_to_reach_medal',
                      namedArgs: {
                        'points': formatAnnualPoints(missing, locale),
                      },
                    ),
                    emphasis: formatAnnualPoints(missing, locale),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: SacFontSize.titleSmall,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  )
                else
                  Text(
                    tr('rankings.annual_progress.top_tier_reached'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: SacFontSize.titleSmall,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 14),
                SacButton(
                  key: const ValueKey('annual-tiers-button'),
                  text: tr('rankings.annual_progress.view_tiers'),
                  variant: SacButtonVariant.secondary,
                  size: SacButtonSize.small,
                  borderRadius: AppTheme.radiusFull,
                  trailingIcon: HugeIcons.strokeRoundedArrowRight01,
                  onPressed: () => showAnnualTiersSheet(
                    context,
                    progress: progress,
                  ),
                ),
              ],
            ],
          ),
        ),
        AnnualYearSummary(progress: progress),
      ],
    );
  }
}

/// No tier configured: only the number, no medal to draw.
class _PointsOnly extends StatelessWidget {
  const _PointsOnly({required this.points});

  final String points;

  @override
  Widget build(BuildContext context) {
    return Text(
      points,
      style: TextStyle(
        color: context.sac.text,
        fontSize: SacFontSize.metric,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.6,
        height: 1,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// The medal, gray underneath and in color from the bottom up to [fraction],
/// with a dashed line at the fill height and a pill with the current points.
class AnnualMedalFill extends StatelessWidget {
  const AnnualMedalFill({
    super.key,
    required this.tier,
    required this.fraction,
    required this.pointsLabel,
    required this.semanticsLabel,
    this.size = kAnnualHeroMedalSize,
  });

  final RankingTier tier;
  final double fraction;
  final String pointsLabel;
  final String semanticsLabel;
  final double size;

  /// Room over the medal for the pill when the fill reaches the top.
  static const double _topRoom = 18;
  static const double _lineWidthExtra = 112;

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    final target = fraction.clamp(0.0, 1.0).toDouble();
    final isFull = target >= 1;

    return Semantics(
      container: true,
      image: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: size + _topRoom,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target),
          duration: reduce ? Duration.zero : SacMotion.routeEnter * 3,
          curve: SacMotion.easeOut,
          builder: (context, value, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (!isFull)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(
                      child: AnnualTierMedal(
                        tier: tier,
                        size: size,
                        unearned: true,
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: size,
                      child: ClipRect(
                        key: const ValueKey('annual-medal-fill'),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          heightFactor: value,
                          child: AnnualTierMedal(tier: tier, size: size),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isFull)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: size * value - 14,
                    child: Center(
                      child: SizedBox(
                        width: size + _lineWidthExtra,
                        height: 28,
                        child: _FillLine(label: pointsLabel),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FillLine extends StatelessWidget {
  const _FillLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);

    return Row(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _DashedLinePainter(color: accent.color),
            size: const Size.fromHeight(28),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent.color,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(color: c.surface, width: 2),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: accent.onColor,
              fontSize: SacFontSize.bodySmall,
              fontWeight: FontWeight.w800,
              height: 1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + 6).clamp(0, size.width), y),
        paint,
      );
      x += 11;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}

/// "ESTE AÑO" group: points of the year and current medal.
class AnnualYearSummary extends StatelessWidget {
  const AnnualYearSummary({super.key, required this.progress});

  final AnnualRankingProgress progress;

  @override
  Widget build(BuildContext context) {
    final locale = annualLocaleOf(context);
    final currentName = progress.currentTier?.name.trim();
    final hasCurrent = currentName != null && currentName.isNotEmpty;

    return SacGroupedSection(
      label: tr('rankings.annual_progress.this_year'),
      action: const SizedBox.shrink(),
      dividerIndent: 16,
      children: [
        _KvRow(
          label: tr('rankings.annual_progress.year_points'),
          value: tr(
            'rankings.annual_progress.year_points_value',
            namedArgs: {
              'earned': formatAnnualPoints(progress.currentPoints, locale),
              'total': formatAnnualPoints(progress.maxPoints, locale),
            },
          ),
        ),
        _KvRow(
          label: tr('rankings.annual_progress.current_medal_label'),
          value: hasCurrent
              ? currentName
              : tr('rankings.annual_progress.no_medal_yet'),
          muted: !hasCurrent,
        ),
      ],
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value, this.muted = false});

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: SacFontSize.titleSmall,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: muted ? c.textTertiary : c.text,
                    fontSize: SacFontSize.titleSmall,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
