import 'package:flutter/material.dart';

/// Shimmer-style skeleton that mirrors the InsuranceView loaded layout.
///
/// Replicates the same shimmer sweep technique used in [FinancesLoadingSkeleton]
/// and [ActivityDetailSkeleton]: a single [AnimationController] drives a
/// [LinearGradient] across every skeleton box so the animation is properly
/// disposed when the widget leaves the tree.
///
/// Structure mirrored:
///   1. InsuranceSummaryHeader — icon + title + badge, progress bar, stat pills
///   2. Search bar
///   3. Status filter chips row
///   4. Sort + count row
///   5. N skeleton MemberInsuranceCard rows
class InsuranceLoadingSkeleton extends StatefulWidget {
  const InsuranceLoadingSkeleton({super.key});

  @override
  State<InsuranceLoadingSkeleton> createState() =>
      _InsuranceLoadingSkeletonState();
}

class _InsuranceLoadingSkeletonState extends State<InsuranceLoadingSkeleton>
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
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. InsuranceSummaryHeader skeleton ──────────────────────────────
          _buildSummaryHeader(context),

          // ── 2. Search bar skeleton ───────────────────────────────────────────
          _buildSearchBar(context),

          // ── 3. Status filter chips skeleton ─────────────────────────────────
          _buildFilterChips(),

          // ── 4. Sort + count row skeleton ────────────────────────────────────
          _buildSortCountRow(),

          const SizedBox(height: 4),

          // ── 5. Member card skeletons ─────────────────────────────────────────
          ...List.generate(6, (i) => _buildMemberCard(context, i)),

          // FAB clearance
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── InsuranceSummaryHeader skeleton ──────────────────────────────────────────

  Widget _buildSummaryHeader(BuildContext context) {
    final sv = _shimmer.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFE8EDF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row: icon container + title text + badge
          Row(
            children: [
              // Icon container
              _SkeletonBox(
                width: 36,
                height: 36,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                shimmerValue: sv,
              ),
              const SizedBox(width: 10),

              // Title label
              _SkeletonBox(width: 150, height: 14, shimmerValue: sv),

              const Spacer(),

              // Coverage percentage badge
              _SkeletonBox(
                width: 46,
                height: 24,
                borderRadius: const BorderRadius.all(Radius.circular(100)),
                shimmerValue: sv,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar
          _SkeletonBox(
            width: double.infinity,
            height: 6,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            shimmerValue: sv,
          ),

          const SizedBox(height: 12),

          // Stat pills row: Total + Asegurados + Vencidos + Sin seguro
          Row(
            children: [
              _SkeletonBox(
                width: 68,
                height: 26,
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                shimmerValue: sv,
              ),
              const SizedBox(width: 8),
              _SkeletonBox(
                width: 88,
                height: 26,
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                shimmerValue: sv,
              ),
              const SizedBox(width: 8),
              _SkeletonBox(
                width: 76,
                height: 26,
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                shimmerValue: sv,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Search bar skeleton ───────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context) {
    final sv = _shimmer.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: _SkeletonBox(
        width: double.infinity,
        height: 46,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        shimmerValue: sv,
      ),
    );
  }

  // ── Status filter chips skeleton ──────────────────────────────────────────────

  Widget _buildFilterChips() {
    final sv = _shimmer.value;
    // Mirror the four InsuranceStatusFilter values: Todos, Asegurados, Vencidos, Sin seguro
    const chipWidths = [56.0, 96.0, 76.0, 92.0];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: chipWidths.length,
        itemBuilder: (_, i) => Padding(
          padding: EdgeInsets.only(right: i < chipWidths.length - 1 ? 8 : 0),
          child: _SkeletonBox(
            width: chipWidths[i],
            height: 28,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            shimmerValue: sv,
          ),
        ),
      ),
    );
  }

  // ── Sort + count row skeleton ─────────────────────────────────────────────────

  Widget _buildSortCountRow() {
    final sv = _shimmer.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // "N miembros" label
          _SkeletonBox(width: 90, height: 13, shimmerValue: sv),
          const Spacer(),
          // Sort dropdown pill
          _SkeletonBox(
            width: 88,
            height: 28,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            shimmerValue: sv,
          ),
        ],
      ),
    );
  }

  // ── Member insurance card skeleton ────────────────────────────────────────────

  Widget _buildMemberCard(BuildContext context, int index) {
    final sv = _shimmer.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFE8EDF2),
          ),
        ),
        child: Row(
          children: [
            // Avatar circle (48x48 with status dot — represented as plain circle)
            _SkeletonBox(
              width: 48,
              height: 48,
              borderRadius: const BorderRadius.all(Radius.circular(100)),
              shimmerValue: sv,
            ),

            const SizedBox(width: 12),

            // Info column: name + class + badge row
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Member name
                  _SkeletonBox(
                    width: _nameWidths[index % _nameWidths.length],
                    height: 14,
                    shimmerValue: sv,
                  ),
                  const SizedBox(height: 4),

                  // Member class (e.g. "Conquistador")
                  _SkeletonBox(width: 80, height: 11, shimmerValue: sv),
                  const SizedBox(height: 8),

                  // Status badge + expiry date
                  Row(
                    children: [
                      _SkeletonBox(
                        width: 72,
                        height: 20,
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
                        shimmerValue: sv,
                      ),
                      const SizedBox(width: 8),
                      _SkeletonBox(width: 100, height: 11, shimmerValue: sv),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Right indicator: arrow or "Registrar" button
            _SkeletonBox(
              width: 20,
              height: 20,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              shimmerValue: sv,
            ),
          ],
        ),
      ),
    );
  }

  // Vary name widths so the skeleton looks natural, not repetitive.
  static const _nameWidths = [140.0, 110.0, 160.0, 95.0, 130.0, 120.0];
}

// ── _SkeletonBox ────────────────────────────────────────────────────────────────
//
// Identical to the one in FinancesLoadingSkeleton and ActivityDetailSkeleton —
// a standalone private class so this file has zero cross-feature imports.

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
