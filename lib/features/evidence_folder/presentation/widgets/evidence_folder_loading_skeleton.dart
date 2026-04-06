import 'package:flutter/material.dart';

class EvidenceFolderLoadingSkeleton extends StatefulWidget {
  const EvidenceFolderLoadingSkeleton({super.key});

  @override
  State<EvidenceFolderLoadingSkeleton> createState() =>
      _EvidenceFolderLoadingSkeletonState();
}

class _EvidenceFolderLoadingSkeletonState
    extends State<EvidenceFolderLoadingSkeleton>
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
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Header card skeleton ─────────────────────────────────────────
          _buildHeaderCard(),
          const SizedBox(height: 10),

          // ── Progress summary row (3 stat pills) ──────────────────────────
          _buildProgressSummaryRow(),
          const SizedBox(height: 16),

          // ── "Secciones" label ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _SkeletonBox(
              width: 90,
              height: 16,
              shimmerValue: _shimmer.value,
            ),
          ),

          // ── Section card skeletons (5 rows) ──────────────────────────────
          ...List.generate(5, (i) => _buildSectionCard(i)),
        ],
      ),
    );
  }

  // ── Header card ─────────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    final sv = _shimmer.value;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre + badge de estado
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _SkeletonBox(width: double.infinity, height: 15, shimmerValue: sv),
              ),
              const SizedBox(width: 10),
              _SkeletonBox(
                width: 68,
                height: 24,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                shimmerValue: sv,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Descripción (2 líneas)
          _SkeletonBox(width: double.infinity, height: 12, shimmerValue: sv),
          const SizedBox(height: 5),
          _SkeletonBox(width: 200, height: 12, shimmerValue: sv),

          const SizedBox(height: 14),
          _SkeletonBox(
            width: double.infinity,
            height: 1,
            borderRadius: BorderRadius.zero,
            shimmerValue: sv,
          ),
          const SizedBox(height: 12),

          // Progress bar + porcentaje
          Row(
            children: [
              Expanded(
                child: _SkeletonBox(
                  width: double.infinity,
                  height: 5,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  shimmerValue: sv,
                ),
              ),
              const SizedBox(width: 10),
              _SkeletonBox(width: 32, height: 12, shimmerValue: sv),
            ],
          ),
          const SizedBox(height: 10),

          // Puntos
          Row(
            children: [
              _SkeletonBox(
                width: 13,
                height: 13,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                shimmerValue: sv,
              ),
              const SizedBox(width: 5),
              _SkeletonBox(width: 100, height: 12, shimmerValue: sv),
            ],
          ),
        ],
      ),
    );
  }

  // ── Progress summary row ─────────────────────────────────────────────────────

  Widget _buildProgressSummaryRow() {
    final sv = _shimmer.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: List.generate(3, (i) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SkeletonBox(width: 24, height: 16, shimmerValue: sv),
                  const SizedBox(height: 4),
                  _SkeletonBox(width: 54, height: 10, shimmerValue: sv),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Section card ─────────────────────────────────────────────────────────────

  Widget _buildSectionCard(int index) {
    final sv = _shimmer.value;
    final nameWidths = [160.0, 140.0, 180.0, 150.0, 170.0];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Ícono de sección
            _SkeletonBox(
              width: 38,
              height: 38,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              shimmerValue: sv,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(
                    width: nameWidths[index % nameWidths.length],
                    height: 14,
                    shimmerValue: sv,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _SkeletonBox(width: 60, height: 11, shimmerValue: sv),
                      const SizedBox(width: 8),
                      _SkeletonBox(
                        width: 50,
                        height: 18,
                        borderRadius: const BorderRadius.all(Radius.circular(20)),
                        shimmerValue: sv,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Chevron
            _SkeletonBox(
              width: 16,
              height: 16,
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
