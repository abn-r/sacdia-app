import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/roadmap_tokens.dart';

/// Header de cada track (Aventureros / Conquistadores / Guías Mayores).
class VATrackHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Color soft;
  final int done;
  final int total;

  /// Si `true`, muestra el pill "Cursando" junto al badge de progreso.
  final bool hasCurrent;

  const VATrackHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.soft,
    required this.done,
    required this.total,
    this.hasCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [soft, Colors.white],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 36,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: RoadmapTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$subtitle · $total clases',
                  style: const TextStyle(
                    fontSize: 12,
                    color: RoadmapTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Pill "Cursando" — visible solo cuando el track tiene la clase actual.
          if (hasCurrent) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: RoadmapTokens.statusCurrent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: RoadmapTokens.statusCurrent.withValues(alpha: 0.4)),
              ),
              child: Text(
                'classes.roadmap.track_current_pill'.tr(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: RoadmapTokens.statusCurrent,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$done/$total',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
