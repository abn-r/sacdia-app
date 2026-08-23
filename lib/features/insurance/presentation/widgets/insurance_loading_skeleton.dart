import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

/// Skeleton que espeja el layout plano de [InsuranceView]:
/// cifra de cobertura, barra, stats, búsqueda, lista agrupada.
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
    );

    _shimmer = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = SacMotion.reduceMotionOf(context);
    if (reduce) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
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
          _buildSummaryHeader(),
          _buildSearchBar(),
          _buildSortCountRow(),
          _buildMemberGroup(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final sv = _shimmer.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: 88, height: 32, shimmerValue: sv),
          const SizedBox(height: 8),
          _SkeletonBox(width: 140, height: 12, shimmerValue: sv),
          const SizedBox(height: 6),
          _SkeletonBox(width: 160, height: 11, shimmerValue: sv),
          const SizedBox(height: 12),
          _SkeletonBox(
            width: double.infinity,
            height: 3,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
            shimmerValue: sv,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _SkeletonBox(width: 28, height: 18, shimmerValue: sv),
                      const SizedBox(height: 6),
                      _SkeletonBox(width: 56, height: 10, shimmerValue: sv),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final sv = _shimmer.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _SkeletonBox(
        width: double.infinity,
        height: 36,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        shimmerValue: sv,
      ),
    );
  }

  Widget _buildSortCountRow() {
    final sv = _shimmer.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          _SkeletonBox(width: 90, height: 12, shimmerValue: sv),
          const Spacer(),
          _SkeletonBox(width: 72, height: 12, shimmerValue: sv),
        ],
      ),
    );
  }

  Widget _buildMemberGroup() {
    final sv = _shimmer.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
          ),
        ),
        child: Column(
          children: List.generate(6, (i) => _buildMemberRow(sv, i, i < 5)),
        ),
      ),
    );
  }

  Widget _buildMemberRow(double sv, int index, bool showSeparator) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              _SkeletonBox(
                width: 36,
                height: 36,
                borderRadius: const BorderRadius.all(Radius.circular(100)),
                shimmerValue: sv,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(
                      width: _nameWidths[index % _nameWidths.length],
                      height: 13,
                      shimmerValue: sv,
                    ),
                    const SizedBox(height: 6),
                    _SkeletonBox(width: 72, height: 10, shimmerValue: sv),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SkeletonBox(width: 64, height: 12, shimmerValue: sv),
            ],
          ),
        ),
        if (showSeparator)
          const Padding(
            padding: EdgeInsets.only(left: 62),
            child: Divider(height: 1, thickness: 0.5),
          ),
      ],
    );
  }

  static const _nameWidths = [140.0, 110.0, 160.0, 95.0, 130.0, 120.0];
}

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
