import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';

/// Skeleton that mirrors the ActivitiesListView loaded layout, built on the
/// shared [SacShimmer] + [SacSkeletonBox] (one shimmer for the whole list;
/// cards carry no fill of their own because the shimmer paints every pixel).
///
/// Structure mirrored (one ActivityCard):
///   Top row:  type badge (pill) + arrow circle button
///   Middle:   title text (2 lines max)
///   Bottom:   metadata row — date icon+text, time icon+text, place icon+text
class ActivitiesLoadingSkeleton extends StatelessWidget {
  const ActivitiesLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SacShimmer(
      child: ExcludeSemantics(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (context, index) => _buildActivityCard(context, index),
        ),
      ),
    );
  }

  // ── ActivityCard skeleton ───────────────────────────────────────────────────

  Widget _buildActivityCard(BuildContext context, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: type badge + arrow circle ───────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Type badge pill
              SacSkeletonBox(
                  width: _badgeWidths[index % _badgeWidths.length],
                  height: 22,
                  radius: AppTheme.radiusLG),

              // Arrow circle button (32×32)
              SacSkeletonBox(
                  width: 32, height: 32, radius: AppTheme.radiusFull),
            ],
          ),
          const SizedBox(height: 10),

          // ── Title (up to 2 lines) ─────────────────────────────────────────
          SacSkeletonBox(
              width: _titleWidths[index % _titleWidths.length], height: 16),
          // Second title line — shown for alternating cards to feel natural
          if (index % 3 == 0) ...[
            const SizedBox(height: 6),
            SacSkeletonBox(
                width: _titleWidths[(index + 2) % _titleWidths.length] * 0.65,
                height: 16),
          ],
          const SizedBox(height: 12),

          // ── Metadata row: date + time + place ─────────────────────────────
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              // Date meta item
              _MetaItemSkeleton(iconSize: 13, labelWidth: 80),
              // Time meta item
              _MetaItemSkeleton(iconSize: 13, labelWidth: 52),
              // Place meta item (slightly wider)
              _MetaItemSkeleton(iconSize: 13, labelWidth: 96),
            ],
          ),
        ],
      ),
    );
  }

  // Vary badge widths so repetition is not obvious.
  static const _badgeWidths = [64.0, 76.0, 80.0, 72.0, 68.0];

  // Vary title widths so skeleton looks organic, not repetitive.
  static const _titleWidths = [200.0, 160.0, 220.0, 140.0, 180.0];
}

// ── _MetaItemSkeleton ─────────────────────────────────────────────────────────
//
// Mirrors the _MetaItem widget in ActivityCard:
//   HugeIcon (13px) + 4px gap + flexible text label.

class _MetaItemSkeleton extends StatelessWidget {
  final double iconSize;
  final double labelWidth;

  const _MetaItemSkeleton({
    required this.iconSize,
    required this.labelWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon placeholder
        SacSkeletonBox(
            width: iconSize, height: iconSize, radius: AppTheme.radiusHairline),
        const SizedBox(width: 4),
        // Text label placeholder
        SacSkeletonBox(width: labelWidth, height: 12),
      ],
    );
  }
}
