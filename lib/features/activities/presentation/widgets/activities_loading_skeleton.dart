import 'package:flutter/material.dart';

/// Shimmer-style skeleton that mirrors the ActivitiesListView loaded layout.
///
/// Replicates the same shimmer sweep technique used in [FinancesLoadingSkeleton],
/// [InsuranceLoadingSkeleton], and [ActivityDetailSkeleton]: a single
/// [AnimationController] drives a [LinearGradient] across every skeleton box
/// so the animation is properly disposed when the widget leaves the tree.
///
/// Structure mirrored (one ActivityCard):
///   Top row:  type badge (pill) + arrow circle button
///   Middle:   title text (2 lines max)
///   Bottom:   metadata row — date icon+text, time icon+text, place icon+text
class ActivitiesLoadingSkeleton extends StatefulWidget {
  const ActivitiesLoadingSkeleton({super.key});

  @override
  State<ActivitiesLoadingSkeleton> createState() =>
      _ActivitiesLoadingSkeletonState();
}

class _ActivitiesLoadingSkeletonState extends State<ActivitiesLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _shimmer = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: 5,
        itemBuilder: (context, index) => _buildActivityCard(context, index),
      ),
    );
  }

  // ── ActivityCard skeleton ───────────────────────────────────────────────────

  Widget _buildActivityCard(BuildContext context, int index) {
    final sv = _shimmer.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8EDF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: type badge + arrow circle ───────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Type badge pill
              _SkeletonBox(
                width: _badgeWidths[index % _badgeWidths.length],
                height: 22,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                shimmerValue: sv,
              ),

              // Arrow circle button (32×32)
              _SkeletonBox(
                width: 32,
                height: 32,
                borderRadius: const BorderRadius.all(Radius.circular(100)),
                shimmerValue: sv,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Title (up to 2 lines) ─────────────────────────────────────────
          _SkeletonBox(
            width: _titleWidths[index % _titleWidths.length],
            height: 16,
            shimmerValue: sv,
          ),
          // Second title line — shown for alternating cards to feel natural
          if (index % 3 == 0) ...[
            const SizedBox(height: 6),
            _SkeletonBox(
              width: _titleWidths[(index + 2) % _titleWidths.length] * 0.65,
              height: 16,
              shimmerValue: sv,
            ),
          ],
          const SizedBox(height: 12),

          // ── Metadata row: date + time + place ─────────────────────────────
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              // Date meta item
              _MetaItemSkeleton(iconSize: 13, labelWidth: 80, shimmerValue: sv),
              // Time meta item
              _MetaItemSkeleton(iconSize: 13, labelWidth: 52, shimmerValue: sv),
              // Place meta item (slightly wider)
              _MetaItemSkeleton(iconSize: 13, labelWidth: 96, shimmerValue: sv),
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
  final double shimmerValue;

  const _MetaItemSkeleton({
    required this.iconSize,
    required this.labelWidth,
    required this.shimmerValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon placeholder
        _SkeletonBox(
          width: iconSize,
          height: iconSize,
          borderRadius: const BorderRadius.all(Radius.circular(3)),
          shimmerValue: shimmerValue,
        ),
        const SizedBox(width: 4),
        // Text label placeholder
        _SkeletonBox(
          width: labelWidth,
          height: 12,
          shimmerValue: shimmerValue,
        ),
      ],
    );
  }
}

// ── _SkeletonBox ───────────────────────────────────────────────────────────────
//
// Identical to the one in FinancesLoadingSkeleton, InsuranceLoadingSkeleton,
// and ActivityDetailSkeleton — a standalone private class so this file has
// zero cross-feature imports.

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final double shimmerValue;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    required this.shimmerValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8EDF2);
    final highlightColor =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F8FB);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment(shimmerValue - 1, 0),
          end: Alignment(shimmerValue + 1, 0),
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
