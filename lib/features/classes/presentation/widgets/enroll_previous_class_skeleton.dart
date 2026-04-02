import 'package:flutter/material.dart';

/// Shimmer-style skeleton that mirrors the [EnrollPreviousClassSheet] loaded
/// layout.
///
/// Replicates the same shimmer sweep technique used in
/// [ActivitiesLoadingSkeleton] and [FinancesLoadingSkeleton]: a single
/// [AnimationController] drives a [LinearGradient] across every skeleton box
/// so the animation is properly disposed when the widget leaves the tree.
///
/// Structure mirrored (inside the sheet, below the static header):
///   1. YearInfo row  — calendar icon + label text + year value pill
///   2. "Seleccioná una clase" label
///   3. N skeleton ClassItem rows — radio circle + logo square + name text
///   4. Confirm button placeholder
class EnrollPreviousClassSkeleton extends StatefulWidget {
  const EnrollPreviousClassSkeleton({super.key});

  @override
  State<EnrollPreviousClassSkeleton> createState() =>
      _EnrollPreviousClassSkeletonState();
}

class _EnrollPreviousClassSkeletonState
    extends State<EnrollPreviousClassSkeleton>
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
      builder: (context, _) {
        final sv = _shimmer.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 1. YearInfo row skeleton ─────────────────────────────────────
            _buildYearInfoSkeleton(context, sv),
            const SizedBox(height: 16),

            // ── 2. Section label skeleton ────────────────────────────────────
            _SkeletonBox(width: 140, height: 13, shimmerValue: sv),
            const SizedBox(height: 10),

            // ── 3. Class item skeletons ──────────────────────────────────────
            ...List.generate(
              5,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildClassItemSkeleton(context, sv, i),
              ),
            ),

            const SizedBox(height: 20),

            // ── 4. Confirm button placeholder ────────────────────────────────
            _SkeletonBox(
              width: double.infinity,
              height: 48,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              shimmerValue: sv,
            ),
          ],
        );
      },
    );
  }

  // ── YearInfo row ────────────────────────────────────────────────────────────
  //
  // Mirrors the Container pill in _buildYearInfo: calendar icon + label + year.

  Widget _buildYearInfoSkeleton(BuildContext context, double sv) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFBFD9F5),
        ),
      ),
      child: Row(
        children: [
          // Calendar icon placeholder
          _SkeletonBox(
            width: 15,
            height: 15,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            shimmerValue: sv,
          ),
          const SizedBox(width: 8),
          // "Año eclesiástico: " label
          _SkeletonBox(width: 120, height: 13, shimmerValue: sv),
          const SizedBox(width: 6),
          // Year value (bolder, shorter)
          _SkeletonBox(width: 48, height: 13, shimmerValue: sv),
        ],
      ),
    );
  }

  // ── ClassItem row ───────────────────────────────────────────────────────────
  //
  // Mirrors one InkWell item in the ListView:
  //   radio circle (20×20) + logo square (36×36) + name text (varies)

  Widget _buildClassItemSkeleton(
      BuildContext context, double sv, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8EDF2),
        ),
      ),
      child: Row(
        children: [
          // Radio button circle
          _SkeletonBox(
            width: 20,
            height: 20,
            borderRadius: const BorderRadius.all(Radius.circular(100)),
            shimmerValue: sv,
          ),
          const SizedBox(width: 10),

          // Class logo square
          _SkeletonBox(
            width: 36,
            height: 36,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            shimmerValue: sv,
          ),
          const SizedBox(width: 10),

          // Class name text — vary widths so it looks organic
          _SkeletonBox(
            width: _nameWidths[index % _nameWidths.length],
            height: 15,
            shimmerValue: sv,
          ),
        ],
      ),
    );
  }

  // Vary name widths to avoid mechanical repetition.
  static const _nameWidths = [160.0, 130.0, 175.0, 145.0, 120.0];
}

// ── _SkeletonBox ───────────────────────────────────────────────────────────────
//
// Identical to the one in ActivitiesLoadingSkeleton, FinancesLoadingSkeleton,
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
