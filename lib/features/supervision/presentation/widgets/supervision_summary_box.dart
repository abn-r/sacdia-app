import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';

/// Content of the grey summary box used at the top of the supervision
/// screens: a label row (label on the left, optional meta on the right), a big
/// number with a secondary «X de Y» text, and a composition bar with its
/// legend.
///
/// Wraps [SacSummaryBox] and [SacStatusBar]; pass already translated text.
/// Do not invent [meta] the API does not return: leave it null.
class SupervisionSummaryBox extends StatelessWidget {
  const SupervisionSummaryBox({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.meta,
    this.segments = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 0),
  });

  /// «Por atender».
  final String label;

  /// The big figure, already formatted («13», «83%»).
  final String value;

  /// Secondary text next to [value] («en 3 de 4 colas»).
  final String? caption;

  /// Right end of the label row («límite 12 nov»).
  final String? meta;

  /// Parts of the whole. Zero-count segments are left out by [SacStatusBar];
  /// give every segment a legend [SacStatusSegment.label].
  final List<SacStatusSegment> segments;

  /// Outer spacing; defaults to the lists' 20 inset.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final meta = this.meta;
    final caption = this.caption;
    final hasBar = segments.any((s) => s.count > 0);
    return Padding(
      padding: padding,
      child: SacSummaryBox(
        color: c.surfaceVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                if (meta != null) ...[
                  const SizedBox(width: 12),
                  // Tight so the meta hugs the right edge instead of
                  // starting at the middle of the row.
                  Flexible(
                    fit: FlexFit.tight,
                    child: Text(
                      meta,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: SacFontSize.displayMedium,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: c.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (caption != null)
                    TextSpan(
                      text: '  ·  $caption',
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (hasBar) ...[
              const SizedBox(height: 12),
              SacStatusBar(segments: segments),
            ],
          ],
        ),
      ),
    );
  }
}
