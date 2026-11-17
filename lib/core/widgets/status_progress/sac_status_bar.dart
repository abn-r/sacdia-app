import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/sac_colors.dart';
import 'sac_status_style.dart';
import 'status_counts.dart';

/// One segment of a [SacStatusBar]: its weight, color and legend text.
class SacStatusSegment {
  const SacStatusSegment({
    required this.count,
    required this.color,
    required this.label,
  });

  final int count;
  final Color color;

  /// Already translated, e.g. "3 validated".
  final String label;
}

/// Already translated legend text for each group of a [StatusCounts].
class SacStatusCountLabels {
  const SacStatusCountLabels({
    required this.validated,
    required this.review,
    required this.rejected,
    required this.pending,
  });

  final String validated;
  final String review;
  final String rejected;
  final String pending;
}

/// Segmented bar with one segment per group, plus a text legend. Segments
/// with a zero count are left out. Gray is "not done", never an error.
///
/// Use the default constructor for any number of custom segments, or
/// [SacStatusBar.counts] for the four standard groups.
class SacStatusBar extends StatelessWidget {
  const SacStatusBar({super.key, required this.segments, this.legendColor})
      : counts = null,
        countLabels = null;

  /// Four standard groups (validated, review, rejected, pending) colored by
  /// [SacStatusStyle].
  const SacStatusBar.counts({
    super.key,
    required StatusCounts this.counts,
    required SacStatusCountLabels this.countLabels,
    this.legendColor,
  }) : segments = null;

  final List<SacStatusSegment>? segments;
  final StatusCounts? counts;
  final SacStatusCountLabels? countLabels;

  /// Legend text color; defaults to secondary text.
  final Color? legendColor;

  List<SacStatusSegment> _resolve(BuildContext context) {
    final custom = segments;
    if (custom != null) return custom;
    final n = counts!;
    final l = countLabels!;
    Color solid(SacStatusKind k) =>
        SacStatusStyle.of(context, k, label: '').solid;
    return [
      SacStatusSegment(
        count: n.validated,
        color: solid(SacStatusKind.validated),
        label: l.validated,
      ),
      SacStatusSegment(
        count: n.review,
        color: solid(SacStatusKind.review),
        label: l.review,
      ),
      SacStatusSegment(
        count: n.rejected,
        color: solid(SacStatusKind.rejected),
        label: l.rejected,
      ),
      SacStatusSegment(
        count: n.pending,
        color: solid(SacStatusKind.pending),
        label: l.pending,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final parts = _resolve(context).where((p) => p.count > 0).toList();

    if (parts.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: parts.map((p) => p.label).join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: SizedBox(
              height: 8,
              child: Row(
                // Without stretch an empty ColoredBox is 0 tall.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < parts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      flex: parts[i].count,
                      child: ColoredBox(color: parts[i].color),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final p in parts)
                Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: p.color,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusHairline,
                              ),
                            ),
                          ),
                        ),
                      ),
                      TextSpan(text: p.label),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    color: legendColor ?? c.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
