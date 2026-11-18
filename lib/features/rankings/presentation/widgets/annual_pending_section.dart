import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/status_progress/sac_grouped_section.dart';
import '../../domain/entities/annual_ranking_progress.dart';
import '../utils/annual_progress_math.dart';
import 'annual_progress_parts.dart';

/// "Proyección" + "POR ENTREGAR" group. [onOpenFolder] opens the annual
/// evidence folder; null makes the rows plain (the user cannot open it).
class AnnualPendingSection extends StatelessWidget {
  const AnnualPendingSection({
    super.key,
    required this.progress,
    required this.onOpenFolder,
  });

  final AnnualRankingProgress progress;
  final VoidCallback? onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final projection = annualProjection(progress);
    final items = progress.pendingItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (projection != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: AnnualProjectionCard(projection: projection),
          ),
        SacGroupedSection(
          label: tr('rankings.annual_progress.pending.group_title'),
          count: items.length,
          action: items.isEmpty ? const SizedBox.shrink() : null,
          dividerIndent: 68,
          children: [
            if (items.isEmpty)
              const _PendingEmptyRow()
            else
              for (final item in items)
                AnnualPendingRow(item: item, onTap: onOpenFolder),
          ],
        ),
      ],
    );
  }
}

/// "Si entregas la carpeta anual": where the points would land, with a bar
/// that shows today solid, the folder hatched and the next medal as a marker.
class AnnualProjectionCard extends StatelessWidget {
  const AnnualProjectionCard({super.key, required this.projection});

  final AnnualProjection projection;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final locale = annualLocaleOf(context);
    final next = projection.nextTier;
    final reaches = projection.reachesNextTier;
    final missing = projection.missingAfter;
    final projected = formatAnnualPoints(projection.projectedPoints, locale);
    final now = formatAnnualPoints(projection.currentPoints, locale);
    final gain = formatAnnualPoints(projection.gain, locale);

    final tail = next == null
        ? null
        : reaches
            ? tr(
                'rankings.annual_progress.projection.reach_tier',
                namedArgs: {'tier': next.name.trim()},
              )
            : tr(
                'rankings.annual_progress.projection.missing_for',
                namedArgs: {
                  'points': formatAnnualPoints(missing ?? 0, locale),
                  'tier': next.name.trim(),
                },
              );

    final semantics = [
      tr(
        'rankings.annual_progress.projection.semantics',
        namedArgs: {'now': now, 'projected': projected},
      ),
      if (tail != null) tail,
    ].join(', ');

    return SacCard(
      key: const ValueKey('annual-projection-card'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('rankings.annual_progress.projection.title').toUpperCase(),
            style: TextStyle(
              fontSize: SacFontSize.labelSmall,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'rankings.annual_progress.projection.reach_points',
              namedArgs: {'points': projected},
            ),
            style: TextStyle(
              color: c.text,
              fontSize: SacFontSize.headlineMedium,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (tail != null) ...[
            const SizedBox(height: 4),
            AnnualEmphasisText(
              text: tail,
              emphasis: reaches ? '' : formatAnnualPoints(missing ?? 0, locale),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: SacFontSize.titleSmall,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Semantics(
            container: true,
            image: true,
            label: semantics,
            excludeSemantics: true,
            child: _ProjectionBar(projection: projection),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _LegendItem(
                swatch: const _Swatch(hatched: false),
                label: tr(
                  'rankings.annual_progress.projection.legend_now',
                  namedArgs: {'points': now},
                ),
              ),
              _LegendItem(
                swatch: const _Swatch(hatched: true),
                label: tr(
                  'rankings.annual_progress.projection.legend_folder',
                  namedArgs: {'points': gain},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectionBar extends StatelessWidget {
  const _ProjectionBar({required this.projection});

  final AnnualProjection projection;

  static const double _height = 38;
  static const double _barHeight = 12;
  static const double _markerSize = 30;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    final reduce = SacMotion.reduceMotionOf(context);
    final max = projection.maxPoints <= 0 ? 1 : projection.maxPoints;
    final nowFraction = (projection.currentPoints / max).clamp(0.0, 1.0);
    final projectedFraction =
        (projection.projectedPoints / max).clamp(0.0, 1.0);
    final next = projection.nextTier;
    final markerFraction =
        next == null ? null : (next.fromPoints / max).clamp(0.0, 1.0);

    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: reduce ? Duration.zero : SacMotion.routeEnter * 2,
            curve: SacMotion.easeOut,
            builder: (context, t, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ProjectionBarPainter(
                      now: nowFraction.toDouble() * t,
                      projected: projectedFraction.toDouble() * t,
                      color: accent,
                      track: annualTrackColor(c),
                      barHeight: _barHeight,
                    ),
                  ),
                ),
                if (markerFraction != null)
                  Positioned(
                    left: (width * markerFraction - _markerSize / 2)
                        .clamp(0.0, width - _markerSize),
                    top: (_height - _markerSize) / 2,
                    child: Container(
                      key: const ValueKey('annual-projection-marker'),
                      width: _markerSize,
                      height: _markerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.surface,
                        border: Border.all(color: c.border),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: AnnualTierMedal(tier: next, size: 24),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProjectionBarPainter extends CustomPainter {
  const _ProjectionBarPainter({
    required this.now,
    required this.projected,
    required this.color,
    required this.track,
    required this.barHeight,
  });

  final double now;
  final double projected;
  final Color color;
  final Color track;
  final double barHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - barHeight) / 2;
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, top, size.width, barHeight),
      Radius.circular(barHeight / 2),
    );
    canvas.drawRRect(bar, Paint()..color = track);

    canvas.save();
    canvas.clipRRect(bar);

    final nowX = size.width * now;
    final projectedX = size.width * projected;
    if (projectedX > nowX) {
      final hatch = Rect.fromLTRB(nowX, top, projectedX, top + barHeight);
      canvas.drawRect(hatch, Paint()..color = color.withValues(alpha: 0.16));
      canvas.save();
      canvas.clipRect(hatch);
      final line = Paint()
        ..color = color.withValues(alpha: 0.7)
        ..strokeWidth = 2;
      for (var x = nowX - barHeight; x < projectedX; x += 5) {
        canvas.drawLine(
          Offset(x, top + barHeight),
          Offset(x + barHeight, top),
          line,
        );
      }
      canvas.restore();
    }
    if (nowX > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, top, nowX, barHeight),
        Paint()..color = color,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProjectionBarPainter old) =>
      old.now != now ||
      old.projected != projected ||
      old.color != color ||
      old.track != track;
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.hatched});

  final bool hatched;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 10),
      painter: _SwatchPainter(
        color: SacAccent.of(context).color,
        hatched: hatched,
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({required this.color, required this.hatched});

  final Color color;
  final bool hatched;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppTheme.radiusHairline),
    );
    if (!hatched) {
      canvas.drawRRect(rrect, Paint()..color = color);
      return;
    }
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.16));
    final line = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.6;
    for (var x = -size.height; x < size.width; x += 4) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        line,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SwatchPainter old) =>
      old.color != color || old.hatched != hatched;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.swatch, required this.label});

  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: context.sac.textSecondary,
            fontSize: SacFontSize.bodySmall,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _PendingEmptyRow extends StatelessWidget {
  const _PendingEmptyRow();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              size: 20,
              color: c.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('rankings.annual_progress.pending.empty'),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: SacFontSize.titleSmall,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One pending section of the annual folder. Tapping opens the folder: the
/// item carries no section id, so there is nothing finer to deep-link to.
class AnnualPendingRow extends StatelessWidget {
  const AnnualPendingRow({super.key, required this.item, required this.onTap});

  final RankingPendingItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final locale = annualLocaleOf(context);
    final tone = _pendingToneFor(context, item);
    final due = item.dueDate;
    final isDelivery = item.statusLabelKey.endsWith('pending_delivery');

    final description = tone.overdue
        ? tr(
            'rankings.annual_progress.pending.overdue_since',
            namedArgs: {'date': formatAnnualDate(due!, locale)},
          )
        : isDelivery && due != null
            ? tr(
                'rankings.annual_progress.pending.due_delivery',
                namedArgs: {'date': formatAnnualDate(due, locale)},
              )
            : tr(item.statusLabelKey);

    return Semantics(
      button: onTap != null,
      container: true,
      excludeSemantics: true,
      label: '${item.title}, $description',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: HugeIcon(
                    icon: tone.icon,
                    size: 20,
                    color: tone.foreground,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: c.text,
                          fontSize: SacFontSize.titleSmall,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color:
                              tone.overdue ? tone.foreground : c.textSecondary,
                          fontSize: SacFontSize.bodyMedium,
                          fontWeight:
                              tone.overdue ? FontWeight.w700 : FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: c.textTertiary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingTone {
  final Color foreground;
  final Color background;
  final HugeIconData icon;
  final bool overdue;

  const _PendingTone({
    required this.foreground,
    required this.background,
    required this.icon,
    this.overdue = false,
  });
}

/// Tone per state: delivery pending (amber), in validation or review (blue),
/// overdue delivery (red). Only a delivery can be overdue: once it is in
/// validation the past date is not the club's fault.
_PendingTone _pendingToneFor(BuildContext context, RankingPendingItem item) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final kind = item.statusLabelKey.split('.').last;
  final isDelivery = kind == 'pending_delivery';
  final due = item.dueDate;
  final today = DateTime.now();
  final overdue = isDelivery &&
      due != null &&
      due.isBefore(DateTime(today.year, today.month, today.day));

  _PendingTone tone({
    required Color color,
    required Color dark,
    required Color bg,
    required HugeIconData icon,
    bool overdue = false,
  }) =>
      _PendingTone(
        foreground: isDark ? color : dark,
        background: isDark ? color.withValues(alpha: 0.18) : bg,
        icon: icon,
        overdue: overdue,
      );

  if (overdue) {
    return tone(
      color: AppColors.rejectedColor,
      dark: AppColors.rejectedDark,
      bg: AppColors.rejectedBg,
      icon: HugeIcons.strokeRoundedAlert02,
      overdue: true,
    );
  }
  if (isDelivery) {
    return tone(
      color: AppColors.observedColor,
      dark: AppColors.observedDark,
      bg: AppColors.observedBg,
      icon: HugeIcons.strokeRoundedUpload01,
    );
  }
  if (kind == 'pending_validation' ||
      kind == 'pending_union_validation' ||
      kind == 'pending_review') {
    return tone(
      color: AppColors.sentColor,
      dark: AppColors.sentDark,
      bg: AppColors.sentBg,
      icon: HugeIcons.strokeRoundedClock01,
    );
  }
  return tone(
    color: AppColors.pendingColor,
    dark: AppColors.pendingDark,
    bg: AppColors.pendingBg,
    icon: HugeIcons.strokeRoundedClock01,
  );
}
