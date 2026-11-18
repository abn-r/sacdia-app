import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/annual_ranking_progress.dart';

const String kAnnualFolderComponentKey = 'annual_evidence_folder';

/// Locale of the app language (EasyLocalization wins over the widget tree,
/// which can differ under a dialog route).
Locale annualLocaleOf(BuildContext context) =>
    EasyLocalization.of(context)?.locale ?? Localizations.localeOf(context);

/// Quantities use the app locale: Spanish reads "1,439" (es_MX), never
/// "1.439", which looks like a decimal in Mexico.
String formatAnnualPoints(int points, Locale locale) {
  final pattern = locale.languageCode == 'es' ? 'es_MX' : locale.toString();
  return NumberFormat.decimalPattern(pattern).format(points);
}

/// Short day + month ("15 nov"); falls back to `dd/MM/yyyy` when the locale
/// data is not loaded.
String formatAnnualDate(DateTime date, Locale locale) {
  try {
    return DateFormat.MMMd(locale.toString()).format(date);
  } catch (_) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

/// Share of the way to the next medal: `currentPoints / nextTier.fromPoints`,
/// clamped to 0..1. Without a next tier the medal is fully earned (1).
double medalFillFraction(AnnualRankingProgress progress) {
  final next = progress.nextTier;
  if (next == null) return 1;
  if (next.fromPoints <= 0) return 1;
  return (progress.currentPoints / next.fromPoints).clamp(0.0, 1.0).toDouble();
}

/// Points missing for the next tier (server value, else derived).
int? pointsToNextTier(AnnualRankingProgress progress) {
  final next = progress.nextTier;
  if (next == null) return null;
  return next.pointsToReach ??
      math.max(0, next.fromPoints - progress.currentPoints);
}

/// Tiers the API tells us about (current and next), highest first.
List<RankingTier> annualKnownTiers(AnnualRankingProgress progress) {
  final bySlug = <String, RankingTier>{};
  for (final tier in [progress.currentTier, progress.nextTier]) {
    if (tier != null) bySlug.putIfAbsent(tier.slug, () => tier);
  }
  return bySlug.values.toList()
    ..sort((a, b) => b.fromPoints.compareTo(a.fromPoints));
}

/// Backend aliases for component keys (see `ranking-component-catalog.ts`).
String normalizeComponentKey(String key) {
  switch (key) {
    case 'annual_folder':
      return 'annual_evidence_folder';
    case 'finance':
      return 'finance_compliance';
    case 'camporee':
      return 'camporee_events';
    default:
      return key;
  }
}

/// Components with something to earn, per axis (or the flat list when the
/// API sends no axes).
List<RankingComponentProgress> annualAllComponents(
  AnnualRankingProgress progress,
) {
  final source = progress.axes.isNotEmpty
      ? progress.axes.expand((axis) => axis.components)
      : progress.components;
  return source.toList();
}

RankingComponentProgress? annualFolderComponent(
  AnnualRankingProgress progress,
) {
  for (final component in annualAllComponents(progress)) {
    if (normalizeComponentKey(component.key) == kAnnualFolderComponentKey) {
      return component;
    }
  }
  return null;
}

/// Component with the most points still to earn (ties: first one). Null when
/// everything is earned.
RankingComponentProgress? componentWithLargestGap(
  Iterable<RankingComponentProgress> components,
) {
  RankingComponentProgress? best;
  var bestGap = 0;
  for (final component in components) {
    if (component.maxPoints <= 0) continue;
    final gap = component.maxPoints - component.earnedPoints;
    if (gap > bestGap) {
      best = component;
      bestGap = gap;
    }
  }
  return best;
}

class AnnualProjection {
  final int currentPoints;
  final int projectedPoints;
  final int maxPoints;
  final RankingTier? nextTier;

  const AnnualProjection({
    required this.currentPoints,
    required this.projectedPoints,
    required this.maxPoints,
    required this.nextTier,
  });

  int get gain => projectedPoints - currentPoints;

  /// True when delivering the folder reaches the next medal.
  bool get reachesNextTier =>
      nextTier != null && projectedPoints >= nextTier!.fromPoints;

  /// Points still missing for the next medal after the folder; null when it
  /// is reached or there is no next tier.
  int? get missingAfter => nextTier == null || reachesNextTier
      ? null
      : nextTier!.fromPoints - projectedPoints;
}

/// "If you deliver the folder": X = current + (folder max - folder earned).
/// Null when the folder is not part of the score or has nothing left.
AnnualProjection? annualProjection(AnnualRankingProgress progress) {
  final folder = annualFolderComponent(progress);
  if (folder == null) return null;
  final remaining = folder.maxPoints - folder.earnedPoints;
  if (remaining <= 0) return null;
  return AnnualProjection(
    currentPoints: progress.currentPoints,
    projectedPoints: progress.currentPoints + remaining,
    maxPoints: progress.maxPoints,
    nextTier: progress.nextTier,
  );
}

/// Heights of the blocks of one column, proportional to `maxPoints` and
/// filling [totalHeight] (gaps included). A block never goes under
/// [minHeight]; the rest shrink in proportion to pay for it.
List<double> allocateBlockHeights(
  List<int> maxPoints, {
  required double totalHeight,
  required double gap,
  required double minHeight,
}) {
  if (maxPoints.isEmpty) return const [];
  final available = totalHeight - gap * (maxPoints.length - 1);
  final sum = maxPoints.fold<int>(0, (a, b) => a + b);
  if (sum <= 0) {
    return List.filled(maxPoints.length, available / maxPoints.length);
  }

  final heights = [for (final m in maxPoints) available * m / sum];
  final small = <int>{
    for (var i = 0; i < heights.length; i++)
      if (heights[i] < minHeight) i,
  };
  if (small.isEmpty) return heights;

  final reserved = small.length * minHeight;
  final bigSum = [
    for (var i = 0; i < maxPoints.length; i++)
      if (!small.contains(i)) maxPoints[i],
  ].fold<int>(0, (a, b) => a + b);
  if (bigSum <= 0) return List.filled(maxPoints.length, minHeight);

  return [
    for (var i = 0; i < maxPoints.length; i++)
      small.contains(i)
          ? minHeight
          : math.max(minHeight, (available - reserved) * maxPoints[i] / bigSum),
  ];
}
