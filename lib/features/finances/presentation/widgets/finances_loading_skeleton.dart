import 'package:flutter/material.dart';

/// Shimmer-style skeleton that mirrors the FinancesView loaded layout.
///
/// Replicates the same shimmer sweep technique used in [ActivityDetailSkeleton]:
/// a single [AnimationController] drives a [LinearGradient] across every
/// skeleton box so the animation is properly disposed when the widget leaves
/// the tree.
///
/// Structure mirrored:
///   1. BalanceHeaderCard  — label + big amount + month nav + income/expense row
///   2. DashedSeparator
///   3. FinanceLineChart   — chart area + period selector chips
///   4. DashedSeparator
///   5. "Transacciones Recientes" section header
///   6. N skeleton TransactionTile rows
class FinancesLoadingSkeleton extends StatefulWidget {
  const FinancesLoadingSkeleton({super.key});

  @override
  State<FinancesLoadingSkeleton> createState() =>
      _FinancesLoadingSkeletonState();
}

class _FinancesLoadingSkeletonState extends State<FinancesLoadingSkeleton>
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
          // ── 1. BalanceHeaderCard skeleton ────────────────────────────────────
          _buildBalanceHeader(),

          // ── 2. Dashed separator placeholder ─────────────────────────────────
          _buildSeparatorPlaceholder(context),

          // ── 3. FinanceLineChart skeleton ─────────────────────────────────────
          _buildChartSkeleton(context),

          // ── 4. Dashed separator placeholder ─────────────────────────────────
          _buildSeparatorPlaceholder(context),

          // ── 5. Transactions section header ───────────────────────────────────
          _buildSectionHeader(),

          // ── 6. Transaction tile skeletons ────────────────────────────────────
          ...List.generate(5, (i) => _buildTransactionTile(context, i)),

          // FAB clearance
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── BalanceHeaderCard skeleton ──────────────────────────────────────────────

  Widget _buildBalanceHeader() {
    final sv = _shimmer.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // "SALDO TOTAL" label
          Center(
            child: _SkeletonBox(width: 90, height: 12, shimmerValue: sv),
          ),
          const SizedBox(height: 10),

          // Big balance amount
          Center(
            child: _SkeletonBox(width: 200, height: 46, shimmerValue: sv),
          ),
          const SizedBox(height: 22),

          // Month navigation row — chevron + label + chevron
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SkeletonBox(
                width: 32,
                height: 32,
                borderRadius: const BorderRadius.all(Radius.circular(100)),
                shimmerValue: sv,
              ),
              const SizedBox(width: 16),
              _SkeletonBox(width: 120, height: 16, shimmerValue: sv),
              const SizedBox(width: 16),
              _SkeletonBox(
                width: 32,
                height: 32,
                borderRadius: const BorderRadius.all(Radius.circular(100)),
                shimmerValue: sv,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Income/expense summary line
          Center(
            child: _SkeletonBox(width: 260, height: 13, shimmerValue: sv),
          ),
        ],
      ),
    );
  }

  // ── Separator placeholder ───────────────────────────────────────────────────

  Widget _buildSeparatorPlaceholder(BuildContext context) {
    // Keep the same vertical rhythm as _DashedSeparator (padding: 20 each side)
    return const SizedBox(height: 41);
  }

  // ── FinanceLineChart skeleton ───────────────────────────────────────────────

  Widget _buildChartSkeleton(BuildContext context) {
    final sv = _shimmer.value;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0A0A0A)
            : const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart header: title + legend dots
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SkeletonBox(width: 130, height: 14, shimmerValue: sv),
              Row(
                children: [
                  _SkeletonBox(
                    width: 60,
                    height: 12,
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                    shimmerValue: sv,
                  ),
                  const SizedBox(width: 12),
                  _SkeletonBox(
                    width: 60,
                    height: 12,
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                    shimmerValue: sv,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart body area — matches the SizedBox(height: 180) in _ChartView
          _SkeletonBox(
            width: double.infinity,
            height: 180,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            shimmerValue: sv,
          ),
          const SizedBox(height: 12),

          // Period selector chips row
          Row(
            children: ['1M', '3M', '6M', '1A', 'Todo']
                .asMap()
                .entries
                .map(
                  (e) => Padding(
                    padding: EdgeInsets.only(right: e.key < 4 ? 8 : 0),
                    child: _SkeletonBox(
                      width: 42,
                      height: 30,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(20)),
                      shimmerValue: sv,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Section header skeleton ─────────────────────────────────────────────────

  Widget _buildSectionHeader() {
    final sv = _shimmer.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SkeletonBox(width: 180, height: 15, shimmerValue: sv),
          _SkeletonBox(width: 60, height: 13, shimmerValue: sv),
        ],
      ),
    );
  }

  // ── Transaction tile skeleton ───────────────────────────────────────────────

  Widget _buildTransactionTile(BuildContext context, int index) {
    final sv = _shimmer.value;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Theme.of(context).brightness == Brightness.dark
            ? null
            : Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Row(
        children: [
          // Emoji icon square
          _SkeletonBox(
            width: 36,
            height: 36,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            shimmerValue: sv,
          ),
          const SizedBox(width: 10),

          // Description + category column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(
                  width: _descriptionWidths[index % _descriptionWidths.length],
                  height: 13,
                  shimmerValue: sv,
                ),
                const SizedBox(height: 6),
                _SkeletonBox(width: 70, height: 11, shimmerValue: sv),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Amount + time column (right-aligned)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SkeletonBox(width: 72, height: 15, shimmerValue: sv),
              const SizedBox(height: 4),
              _SkeletonBox(width: 50, height: 10, shimmerValue: sv),
              const SizedBox(height: 4),
              // registeredBy row: CircleAvatar(r:6) + name text ≈ 12px
              _SkeletonBox(
                width: 60,
                height: 12,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                shimmerValue: sv,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Vary description widths so the skeleton looks natural, not repetitive.
  static const _descriptionWidths = [140.0, 110.0, 160.0, 90.0, 130.0];
}

// ── _SkeletonBox ───────────────────────────────────────────────────────────────
//
// Identical to the one in ActivityDetailSkeleton — a standalone private class
// so this file has zero cross-feature imports.

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
