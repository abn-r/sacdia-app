import 'package:flutter/material.dart';

class AnnualFolderLoadingSkeleton extends StatefulWidget {
  const AnnualFolderLoadingSkeleton({super.key});

  @override
  State<AnnualFolderLoadingSkeleton> createState() =>
      _AnnualFolderLoadingSkeletonState();
}

class _AnnualFolderLoadingSkeletonState
    extends State<AnnualFolderLoadingSkeleton>
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
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Header card skeleton ─────────────────────────────────────────
          _buildHeaderCard(),
          const SizedBox(height: 16),

          // ── "Secciones" label ────────────────────────────────────────────
          _SkeletonBox(width: 90, height: 16, shimmerValue: _shimmer.value),
          const SizedBox(height: 12),

          // ── Section cards skeleton (5 rows) ──────────────────────────────
          ...List.generate(5, (i) => _buildSectionCard(i)),

          const SizedBox(height: 24),

          // ── Submit button placeholder ─────────────────────────────────────
          _SkeletonBox(
            width: double.infinity,
            height: 50,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            shimmerValue: _shimmer.value,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final sv = _shimmer.value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonBox(
                width: 40,
                height: 40,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                shimmerValue: sv,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 130, height: 16, shimmerValue: sv),
                    const SizedBox(height: 6),
                    _SkeletonBox(width: 180, height: 12, shimmerValue: sv),
                  ],
                ),
              ),
              _SkeletonBox(
                width: 72,
                height: 24,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                shimmerValue: sv,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SkeletonBox(
            width: double.infinity,
            height: 6,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            shimmerValue: sv,
          ),
          const SizedBox(height: 6),
          _SkeletonBox(width: 160, height: 11, shimmerValue: sv),
        ],
      ),
    );
  }

  Widget _buildSectionCard(int index) {
    final sv = _shimmer.value;
    final widths = [160.0, 140.0, 180.0, 150.0, 170.0];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : const Color(0xFFF8FAFC),
        ),
        child: Row(
          children: [
            _SkeletonBox(
              width: 36,
              height: 36,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              shimmerValue: sv,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(
                    width: widths[index % widths.length],
                    height: 14,
                    shimmerValue: sv,
                  ),
                  const SizedBox(height: 6),
                  _SkeletonBox(width: 80, height: 12, shimmerValue: sv),
                ],
              ),
            ),
            _SkeletonBox(
              width: 18,
              height: 18,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              shimmerValue: sv,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SkeletonBox ──────────────────────────────────────────────────────────────

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
