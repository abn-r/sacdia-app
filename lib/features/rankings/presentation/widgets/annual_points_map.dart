import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../domain/entities/annual_ranking_progress.dart';
import '../utils/annual_progress_math.dart';
import 'annual_progress_parts.dart';

/// Components the backend can score; each has a plain-language explanation.
const Set<String> kAnnualExplainedComponents = {
  'annual_evidence_folder',
  'monthly_reports_timeliness',
  'finance_compliance',
  'institutional_data_completeness',
  'activities_registered',
  'attendance_participation',
  'camporee_events',
  'class_investiture_progress',
  'sacdia_operational_usage',
};

/// Total height of the map; the blocks of a column share it by `maxPoints`.
const double kAnnualMapHeight = 380;
const double _kBlockGap = 8;
const double _kBlockMinHeight = 68;

class _MapColumn {
  const _MapColumn({
    required this.label,
    required this.color,
    required this.components,
  });

  final String? label;
  final Color color;
  final List<RankingComponentProgress> components;
}

List<_MapColumn> _columnsFor(AnnualRankingProgress progress) {
  if (progress.axes.isEmpty) {
    final components =
        progress.components.where((c) => c.maxPoints > 0).toList();
    return components.isEmpty
        ? const []
        : [
            _MapColumn(
              label: null,
              color: annualAxisColor('', 0),
              components: components,
            ),
          ];
  }

  return [
    for (var i = 0; i < progress.axes.length; i++)
      if (progress.axes[i].components.any((c) => c.maxPoints > 0))
        _MapColumn(
          label: progress.axes[i].label,
          color: annualAxisColor(progress.axes[i].key, i),
          components: progress.axes[i].components
              .where((c) => c.maxPoints > 0)
              .toList(),
        ),
  ];
}

/// "Mapa de bloques": one column per axis, one block per component whose
/// height is proportional to what it is worth and that fills from the bottom
/// with what was earned. Tapping a block explains how those points are won.
class AnnualPointsMap extends StatelessWidget {
  const AnnualPointsMap({super.key, required this.progress});

  final AnnualRankingProgress progress;

  @override
  Widget build(BuildContext context) {
    final columns = _columnsFor(progress);
    if (columns.isEmpty) return const SizedBox.shrink();

    final c = context.sac;
    final locale = annualLocaleOf(context);
    final gapComponent = componentWithLargestGap(
      columns.expand((col) => col.components),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnnualEyebrow(
          label: tr('rankings.annual_progress.components_title'),
          trailing: formatAnnualPoints(progress.currentPoints, locale),
        ),
        if (progress.axes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final col in columns)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: col.color,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusHairline),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        col.label ?? '',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: SacFontSize.bodySmall,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: kAnnualMapHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  if (i > 0) const SizedBox(width: _kBlockGap),
                  Expanded(
                    child: _MapColumnView(
                      column: columns[i],
                      gapComponent: gapComponent,
                      locale: locale,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Text(
            tr('rankings.annual_progress.blocks_hint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textTertiary,
              fontSize: SacFontSize.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapColumnView extends StatelessWidget {
  const _MapColumnView({
    required this.column,
    required this.gapComponent,
    required this.locale,
  });

  final _MapColumn column;
  final RankingComponentProgress? gapComponent;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final heights = allocateBlockHeights(
      [for (final comp in column.components) comp.maxPoints],
      totalHeight: kAnnualMapHeight,
      gap: _kBlockGap,
      minHeight: _kBlockMinHeight,
    );

    return Column(
      children: [
        for (var i = 0; i < column.components.length; i++) ...[
          if (i > 0) const SizedBox(height: _kBlockGap),
          SizedBox(
            height: heights[i],
            child: AnnualComponentBlock(
              key: ValueKey('annual-block-${column.components[i].key}'),
              component: column.components[i],
              color: column.color,
              axisLabel: column.label,
              locale: locale,
              showGainChip: identical(column.components[i], gapComponent),
            ),
          ),
        ],
      ],
    );
  }
}

class AnnualComponentBlock extends StatelessWidget {
  const AnnualComponentBlock({
    super.key,
    required this.component,
    required this.color,
    required this.axisLabel,
    required this.locale,
    required this.showGainChip,
  });

  final RankingComponentProgress component;
  final Color color;
  final String? axisLabel;
  final Locale locale;
  final bool showGainChip;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduce = SacMotion.reduceMotionOf(context);
    final fraction = component.maxPoints <= 0
        ? 0.0
        : (component.earnedPoints / component.maxPoints)
            .clamp(0.0, 1.0)
            .toDouble();
    final gain = component.maxPoints - component.earnedPoints;
    final earned = formatAnnualPoints(component.earnedPoints, locale);
    final max = formatAnnualPoints(component.maxPoints, locale);
    final ratio = tr(
      'rankings.annual_progress.component_points',
      namedArgs: {'earned': earned, 'max': max},
    );
    final radius = BorderRadius.circular(AppTheme.radiusSM);
    final tint = Color.alphaBlend(
      color.withValues(alpha: isDark ? 0.18 : 0.12),
      c.surface,
    );

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${component.label}, $ratio',
      hint: tr('rankings.annual_progress.block_hint'),
      onTap: () => showAnnualComponentSheet(
        context,
        component: component,
        axisLabel: axisLabel,
        color: color,
      ),
      child: Material(
        color: tint,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showAnnualComponentSheet(
            context,
            component: component,
            axisLabel: axisLabel,
            color: color,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: fraction),
                  duration: reduce ? Duration.zero : SacMotion.routeEnter * 2,
                  curve: SacMotion.easeOut,
                  builder: (context, value, _) => Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      key: ValueKey('annual-fill-${component.key}'),
                      widthFactor: 1,
                      heightFactor: value,
                      child: ColoredBox(
                        color: color.withValues(alpha: isDark ? 0.42 : 0.34),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        component.label,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.text,
                          fontSize: SacFontSize.bodyMedium,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        ratio,
                        maxLines: 1,
                        style: TextStyle(
                          color: c.text,
                          fontSize: SacFontSize.bodySmall,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (showGainChip && gain > 0) ...[
                      const SizedBox(height: 6),
                      _GainChip(
                        label: tr(
                          'rankings.annual_progress.points_to_earn',
                          namedArgs: {
                            'points': formatAnnualPoints(gain, locale),
                          },
                        ),
                      ),
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

class _GainChip extends StatelessWidget {
  const _GainChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      key: const ValueKey('annual-gain-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: c.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: c.text,
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Sheet of one component: how much it gives and how those points are won.
Future<void> showAnnualComponentSheet(
  BuildContext context, {
  required RankingComponentProgress component,
  required String? axisLabel,
  required Color color,
}) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AnnualComponentSheet(
      component: component,
      axisLabel: axisLabel,
      color: color,
    ),
  );
}

class AnnualComponentSheet extends StatelessWidget {
  const AnnualComponentSheet({
    super.key,
    required this.component,
    required this.axisLabel,
    required this.color,
  });

  final RankingComponentProgress component;
  final String? axisLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final locale = annualLocaleOf(context);
    final key = normalizeComponentKey(component.key);
    final explanation = kAnnualExplainedComponents.contains(key)
        ? tr('rankings.annual_progress.component_explain.$key')
        : tr('rankings.annual_progress.component_explain.generic');

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(title: component.label, showClose: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      'rankings.annual_progress.component_points',
                      namedArgs: {
                        'earned': formatAnnualPoints(
                          component.earnedPoints,
                          locale,
                        ),
                        'max': formatAnnualPoints(component.maxPoints, locale),
                      },
                    ),
                    style: TextStyle(
                      color: c.text,
                      fontSize: SacFontSize.displaySmall,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (axisLabel != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusHairline),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr(
                              'rankings.annual_progress.component_axis',
                              namedArgs: {'axis': axisLabel!},
                            ),
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: SacFontSize.bodyMedium,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    tr('rankings.annual_progress.how_it_is_earned')
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: SacFontSize.labelSmall,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: c.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    explanation,
                    style: TextStyle(
                      color: c.text,
                      fontSize: SacFontSize.titleSmall,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
